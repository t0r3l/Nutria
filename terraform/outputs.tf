# ALB Outputs
output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

# API Gateway Outputs
output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_endpoints" {
  description = "API endpoints"
  value = {
    targets  = "${aws_api_gateway_stage.main.invoke_url}/targets"
    optimize = "${aws_api_gateway_stage.main.invoke_url}/optimize"
  }
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.meal_optimizer.name
}

# ECR Output
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.meal_optimizer.repository_url
}

# S3 Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.s3.bucket_name
}

output "s3_csv_key" {
  description = "S3 key of the CSV file"
  value       = module.s3.csv_object_key
}

# Lambda Outputs
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.compute_targets.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.compute_targets.arn
}