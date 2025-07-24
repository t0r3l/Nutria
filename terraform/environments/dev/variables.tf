variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones_count" {
  description = "Number of availability zones"
  type        = number
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units"
  type        = string
}

variable "fargate_memory" {
  description = "Fargate instance memory in MB"
  type        = string
}

variable "app_count" {
  description = "Number of docker containers to run"
  type        = number
}

variable "ecs_autoscale_min_instances" {
  description = "Minimum number of ECS instances"
  type        = number
}

variable "ecs_autoscale_max_instances" {
  description = "Maximum number of ECS instances"
  type        = number
}

variable "lambda_timeout" {
  description = "Lambda function timeout"
  type        = number
}

variable "lambda_memory" {
  description = "Lambda function memory"
  type        = number
}

variable "csv_file_path" {
  description = "Path to the CSV data file"
  type        = string
}