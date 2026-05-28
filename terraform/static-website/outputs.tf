##############################################################################
# outputs.tf
# Exposes the stable consumer interface for this stack.
# Only values that callers genuinely need are exported; full provider objects
# are intentionally omitted to keep the interface narrow and reviewable.
##############################################################################

output "cloudfront_url" {
  description = "HTTPS URL of the CloudFront distribution. Open this in a browser to view the static website."
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket that stores the website assets. Use this when uploading files with the AWS CLI or SDK."
  value       = aws_s3_bucket.website.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID. Required when creating cache invalidations after deploying new content (e.g. aws cloudfront create-invalidation --distribution-id <id> --paths '/*')."
  value       = aws_cloudfront_distribution.website.id
}
