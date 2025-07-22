locals {
  # Common naming
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Region      = var.aws_region
    }
  )
  
  # ECR repository URI
  ecr_repository_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  
  # S3 bucket name
  s3_bucket_name = "${local.name_prefix}-nutrition-data-${random_id.bucket_suffix.hex}"
  
  # CSV file key in S3
  csv_file_key = "data/products_nutrition.csv"
}