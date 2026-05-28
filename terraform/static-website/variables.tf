##############################################################################
# variables.tf
# All input variables for the static-website stack.
# Attribute order follows the project coding standard:
#   description → type → default → nullable → sensitive → validation
##############################################################################

variable "bucket_name_prefix" {
  description = "Short prefix used to build the S3 bucket name. A random hex suffix and the environment name are appended automatically to ensure global uniqueness."
  type        = string
  default     = "my-static-site"
}

variable "environment" {
  description = "Deployment environment label (e.g. dev, staging, prod). Included in the bucket name and resource tags."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region in which the S3 bucket is created. CloudFront is a global service and is always deployed to us-east-1 internally."
  type        = string
  default     = "us-east-1"
}

variable "cloudfront_price_class" {
  description = <<-EOT
    CloudFront price class that controls which edge locations serve the distribution.
      PriceClass_100 — North America and Europe only (cheapest).
      PriceClass_200 — North America, Europe, Asia, Middle East, and Africa.
      PriceClass_All — All edge locations worldwide (most expensive).
  EOT
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "cloudfront_price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "tags" {
  description = "Map of additional tags applied to every resource. The provider default_tags block merges these automatically."
  type        = map(string)
  default = {
    Project   = "static-site"
    ManagedBy = "terraform"
  }
}
