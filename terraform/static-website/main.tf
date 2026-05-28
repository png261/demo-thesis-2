##############################################################################
# main.tf
# Static website infrastructure: private S3 bucket + CloudFront with OAC.
#
# Architecture summary
# ────────────────────
#  Browser → CloudFront (HTTPS only) → S3 (private, OAC sigv4)
#
# Security posture
# ────────────────
#  • S3 bucket has ALL public-access block flags enabled.
#  • Only the CloudFront service principal (cloudfront.amazonaws.com) may
#    call s3:GetObject, and only when the request originates from THIS
#    specific distribution (aws:SourceArn condition).
#  • All viewer connections are redirected to HTTPS.
#  • Bucket versioning is enabled for accidental-deletion recovery.
#  • Server-side encryption (AES-256 / SSE-S3) is enforced at rest.
##############################################################################

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  # Globally unique bucket name: <prefix>-<env>-<8-char hex>
  bucket_name = "${var.bucket_name_prefix}-${var.environment}-${random_id.suffix.hex}"
}

# ---------------------------------------------------------------------------
# Random suffix — ensures the S3 bucket name is globally unique across
# accounts and re-deployments without requiring manual input.
# ---------------------------------------------------------------------------
resource "random_id" "suffix" {
  byte_length = 4 # produces an 8-character lowercase hex string
}

# ---------------------------------------------------------------------------
# S3 Bucket
# The bucket is intentionally private; CloudFront accesses it via OAC.
# force_destroy is false to prevent accidental data loss on `terraform destroy`.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "website" {
  bucket        = local.bucket_name
  force_destroy = false

  tags = {
    Name        = local.bucket_name
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------
# Bucket versioning
# Keeps previous object versions so accidental overwrites or deletions can
# be recovered without a full re-deploy.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------------------------
# Server-side encryption
# AES-256 (SSE-S3) encrypts every object at rest using AWS-managed keys.
# No additional cost; no KMS key management overhead for a public website.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# Public access block
# All four flags are set to true so that no ACL or bucket policy can ever
# accidentally expose objects to the public internet directly via S3.
# CloudFront OAC bypasses this restriction because it uses IAM sigv4, not
# public S3 URLs.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# CloudFront Origin Access Control (OAC)
# OAC is the modern replacement for Origin Access Identity (OAI).
# It signs every request to S3 with SigV4, so S3 can verify the request
# genuinely came from this CloudFront distribution.
# ---------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${local.bucket_name}-oac"
  description                       = "OAC for ${local.bucket_name} static website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------------------------------------------------------------------------
# CloudFront Distribution
# Serves the static website over HTTPS from the nearest edge location.
# ---------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  http_version        = "http2and3"
  price_class         = var.cloudfront_price_class
  comment             = "${var.environment} static website — ${local.bucket_name}"

  # ── Origin: private S3 bucket accessed via OAC ──────────────────────────
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "s3-${local.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  # ── Default cache behaviour ──────────────────────────────────────────────
  default_cache_behavior {
    target_origin_id       = "s3-${local.bucket_name}"
    viewer_protocol_policy = "redirect-to-https" # HTTP → HTTPS redirect

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    # Use the AWS-managed CachingOptimized policy (ID is stable across all
    # accounts and regions — no data source lookup required).
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    compress = true # Gzip/Brotli compression at the edge
  }

  # ── Custom error responses ───────────────────────────────────────────────
  # 403 Forbidden: S3 returns 403 for missing objects when the bucket is
  # private. Rewrite to index.html with HTTP 200 so SPA client-side routing
  # works correctly.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  # 404 Not Found: return index.html with HTTP 404 so search engines and
  # monitoring tools still see the correct status code.
  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  # ── Geographic restrictions ──────────────────────────────────────────────
  # No geo-blocking by default; remove the none block and add an allowlist
  # or denylist here if required.
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # ── TLS certificate ──────────────────────────────────────────────────────
  # Use the default CloudFront certificate (*.cloudfront.net).
  # To attach a custom domain, replace this block with an ACM certificate ARN
  # and add an aliases argument.
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.environment}-static-website"
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------
# S3 Bucket Policy
# Grants CloudFront OAC permission to call s3:GetObject on this bucket.
#
# The aws:SourceArn condition scopes the permission to THIS distribution only,
# preventing any other CloudFront distribution from reading the bucket even if
# it somehow referenced the same origin.
#
# depends_on is explicit because:
#   1. aws_s3_bucket_public_access_block — AWS rejects bucket policies that
#      grant public access while the block is being applied; the block must
#      exist first.
#   2. aws_cloudfront_distribution — the distribution ARN must exist before
#      it can be referenced in the condition.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOACGetObject"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.website,
    aws_cloudfront_distribution.website,
  ]
}
