# Random ID for unique naming
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name_prefix              = local.name_prefix
  vpc_cidr                 = var.vpc_cidr
  availability_zones_count = var.availability_zones_count
  tags                     = local.common_tags
}

# S3 Module
module "s3" {
  source = "./modules/s3"

  bucket_name   = local.s3_bucket_name
  csv_file_path = var.csv_file_path
  csv_file_key  = local.csv_file_key
  tags          = local.common_tags
}

# Security Groups
resource "aws_security_group" "fargate_sg" {
  name        = "${local.name_prefix}-fargate-sg"
  description = "Security group for Fargate tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-fargate-sg"
    }
  )
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
    }
  )
}