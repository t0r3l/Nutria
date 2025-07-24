terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "nutria" {
  source = "../.."

  # Pass all variables to the root module
  project_name                = var.project_name
  environment                 = var.environment
  aws_region                  = var.aws_region
  vpc_cidr                   = var.vpc_cidr
  availability_zones_count   = var.availability_zones_count
  fargate_cpu                = var.fargate_cpu
  fargate_memory             = var.fargate_memory
  app_count                  = var.app_count
  ecs_autoscale_min_instances = var.ecs_autoscale_min_instances
  ecs_autoscale_max_instances = var.ecs_autoscale_max_instances
  lambda_timeout             = var.lambda_timeout
  lambda_memory              = var.lambda_memory
  csv_file_path              = var.csv_file_path
}

# Output all the module outputs
output "ecr_repository_url" {
  value = module.nutria.ecr_repository_url
}

output "ecs_cluster_name" {
  value = module.nutria.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.nutria.ecs_service_name
}

output "alb_url" {
  value = module.nutria.alb_url
}

output "api_gateway_url" {
  value = module.nutria.api_gateway_url
}