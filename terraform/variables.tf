# Project Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "nutria"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# AWS Configuration
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-3"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

# Data Configuration
variable "csv_file_path" {
  description = "Path to local CSV file"
  type        = string
  default     = "/home/torel/IdeaProjects/NutriaIngestionAndSolver/data_prep/data/products_names_with_macro_nutriments(in).csv"
}

# ECS Configuration
variable "fargate_cpu" {
  description = "Fargate CPU units"
  type        = string
  default     = "1024"
}

variable "fargate_memory" {
  description = "Fargate memory in MB"
  type        = string
  default     = "2048"
}

variable "app_count" {
  description = "Number of app containers to run"
  type        = number
  default     = 2
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

# Auto Scaling Configuration
variable "ecs_autoscale_min_instances" {
  description = "Minimum number of ECS instances"
  type        = number
  default     = 1
}

variable "ecs_autoscale_max_instances" {
  description = "Maximum number of ECS instances"
  type        = number
  default     = 4
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 512
}

# Tags
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}