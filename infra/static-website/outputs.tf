output "cloudfront_domain_name" {
  description = "The CloudFront distribution domain name. Use this as your website URL (e.g. https://<value>)."
  value       = aws_cloudfront_distribution.website.domain_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket holding website assets."
  value       = aws_s3_bucket.website.id
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution. Use this to create cache invalidations."
  value       = aws_cloudfront_distribution.website.id
}
