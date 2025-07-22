# Configure AWS provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}