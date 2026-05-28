##############################################################################
# versions.tf
# Declares the Terraform runtime floor and provider version constraints.
# Pinning lower bounds prevents silent breakage from incompatible provider
# releases while still allowing patch-level upgrades within a minor series.
##############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Provider configuration
# The region is driven by the aws_region variable so callers can override it
# without touching provider blocks.
# ---------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}
