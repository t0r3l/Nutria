# main.tf - Updated with Fargate for meal optimizer

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Variables
variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "nutria"
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-3"
}

variable "csv_file_path" {
  description = "Chemin vers le fichier CSV local"
  type        = string
  default     = "/home/torel/IdeaProjects/NutriaIngestionAndSolver/data_prep/data/products_names_with_macro_nutriments(in).csv"
}

# Configure AWS provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Region      = var.aws_region
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Random ID for unique naming
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# VPC for Fargate
resource "aws_vpc" "nutria_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Public subnets for Fargate
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.nutria_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "nutria_igw" {
  vpc_id = aws_vpc.nutria_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.nutria_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nutria_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route table associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security group for Fargate
resource "aws_security_group" "fargate_sg" {
  name_prefix = "${var.project_name}-fargate-"
  vpc_id      = aws_vpc.nutria_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-fargate-sg"
  }
}

# S3 bucket for nutrition data
resource "aws_s3_bucket" "nutrition_data" {
  bucket = "${var.project_name}-nutrition-data-${var.environment}-${random_id.bucket_suffix.hex}"

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name        = "${var.project_name}-nutrition-data"
    Environment = var.environment
    Project     = var.project_name
    Region      = var.aws_region
  }
}

# S3 bucket configuration
resource "aws_s3_bucket_versioning" "nutrition_data_versioning" {
  bucket = aws_s3_bucket.nutrition_data.id
  versioning_configuration {
    status = "Enabled"
  }
  depends_on = [aws_s3_bucket.nutrition_data]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "nutrition_data_encryption" {
  bucket = aws_s3_bucket.nutrition_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
  depends_on = [aws_s3_bucket.nutrition_data]
}

resource "aws_s3_bucket_public_access_block" "nutrition_data_pab" {
  bucket = aws_s3_bucket.nutrition_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.nutrition_data]
}

# Upload CSV file to S3
resource "aws_s3_object" "products_csv" {
  bucket = aws_s3_bucket.nutrition_data.id
  key    = "data/products_names_with_macro_nutriments.csv"
  source = var.csv_file_path
  etag   = filemd5(var.csv_file_path)

  tags = {
    Name        = "nutrition-products-data"
    Environment = var.environment
  }

  depends_on = [
    aws_s3_bucket.nutrition_data,
    aws_s3_bucket_versioning.nutrition_data_versioning
  ]
}

# ECR repository for meal optimizer
resource "aws_ecr_repository" "meal_optimizer" {
  name = "${var.project_name}/meal-optimizer"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-meal-optimizer-repo"
    Environment = var.environment
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "nutria_cluster" {
  name = "${var.project_name}-cluster-${random_id.bucket_suffix.hex}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# IAM role for ECS task execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role-${random_id.bucket_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# IAM role for ECS task
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role-${random_id.bucket_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policies
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_execution_role.name
}

resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "${var.project_name}-ecs-s3-policy-${random_id.bucket_suffix.hex}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.nutrition_data.arn,
          "${aws_s3_bucket.nutrition_data.arn}/*"
        ]
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "meal_optimizer" {
  family                   = "${var.project_name}-meal-optimizer"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"   # 0.5 vCPU
  memory                   = "1024"  # 1GB RAM
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "meal-optimizer"
      image = "${aws_ecr_repository.meal_optimizer.repository_url}:latest"

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "S3_BUCKET_NAME"
          value = aws_s3_bucket.nutrition_data.id
        },
        {
          name  = "CSV_FILE_KEY"
          value = "data/products_names_with_macro_nutriments.csv"
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-meal-optimizer"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name = "${var.project_name}-meal-optimizer-task"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}-meal-optimizer"
  retention_in_days = 14

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Application Load Balancer
resource "aws_lb" "nutria_alb" {
  name               = "${var.project_name}-alb-${substr(random_id.bucket_suffix.hex, 0, 6)}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.fargate_sg.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "meal_optimizer_tg" {
  name        = "${var.project_name}-tg-${substr(random_id.bucket_suffix.hex, 0, 6)}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.nutria_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-target-group"
  }
}

# ALB Listener
resource "aws_lb_listener" "nutria_listener" {
  load_balancer_arn = aws_lb.nutria_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.meal_optimizer_tg.arn
  }
}

# ECS Service
resource "aws_ecs_service" "meal_optimizer" {
  name            = "${var.project_name}-meal-optimizer-service"
  cluster         = aws_ecs_cluster.nutria_cluster.id
  task_definition = aws_ecs_task_definition.meal_optimizer.arn
  desired_count   = 0  # Starts at 0, scales up on demand

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight           = 100
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.fargate_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.meal_optimizer_tg.arn
    container_name   = "meal-optimizer"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.nutria_listener]

  tags = {
    Name = "${var.project_name}-meal-optimizer-service"
  }
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.nutria_cluster.name}/${aws_ecs_service.meal_optimizer.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy
resource "aws_appautoscaling_policy" "ecs_policy" {
  name               = "${var.project_name}-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Lambda components (keep existing targets Lambda)
resource "null_resource" "create_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p builds lambda_functions/targets"
  }
}

# Lambda layer for targets
resource "aws_lambda_layer_version" "targets_layer" {
  filename         = "layers/targets_layer.zip"
  layer_name       = "${var.project_name}-targets-utilities-${random_id.bucket_suffix.hex}"
  description      = "Basic nutrition calculation utilities for targets Lambda"

  compatible_runtimes = ["python3.11"]

  source_code_hash = filebase64sha256("layers/targets_layer.zip")
}

# Lambda deployment package for targets
data "archive_file" "targets_lambda_zip" {
  type        = "zip"
  source_dir  = "lambda_functions/targets"
  output_path = "builds/targets_lambda.zip"
  depends_on  = [null_resource.create_dirs]
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role-${random_id.bucket_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "compute_targets_logs" {
  name              = "/aws/lambda/${var.project_name}-compute-targets-${random_id.bucket_suffix.hex}"
  retention_in_days = 14
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lambda Function - Compute Targets
resource "aws_lambda_function" "compute_targets" {
  filename         = data.archive_file.targets_lambda_zip.output_path
  function_name    = "${var.project_name}-compute-targets-${random_id.bucket_suffix.hex}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "lambda_function.computeTargets"
  source_code_hash = data.archive_file.targets_lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256

  layers = [aws_lambda_layer_version.targets_layer.arn]

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-compute-targets"
    Environment = var.environment
    Deployment  = "layer"
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.compute_targets_logs
  ]
}

# API Gateway
resource "aws_api_gateway_rest_api" "nutrition_api" {
  name        = "${var.project_name}-api-${random_id.bucket_suffix.hex}"
  description = "Hybrid API: Lambda targets + Fargate optimization"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
  }
}

# API Gateway Resources and Methods for Targets (Lambda)
resource "aws_api_gateway_resource" "compute_targets_resource" {
  rest_api_id = aws_api_gateway_rest_api.nutrition_api.id
  parent_id   = aws_api_gateway_rest_api.nutrition_api.root_resource_id
  path_part   = "targets"
}

resource "aws_api_gateway_method" "compute_targets_method" {
  rest_api_id   = aws_api_gateway_rest_api.nutrition_api.id
  resource_id   = aws_api_gateway_resource.compute_targets_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "compute_targets_integration" {
  rest_api_id = aws_api_gateway_rest_api.nutrition_api.id
  resource_id = aws_api_gateway_resource.compute_targets_resource.id
  http_method = aws_api_gateway_method.compute_targets_method.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.compute_targets.invoke_arn
}

# API Gateway Resources and Methods for Optimizer (Fargate via HTTP proxy)
resource "aws_api_gateway_resource" "meal_optimizer_resource" {
  rest_api_id = aws_api_gateway_rest_api.nutrition_api.id
  parent_id   = aws_api_gateway_rest_api.nutrition_api.root_resource_id
  path_part   = "optimize"
}

resource "aws_api_gateway_method" "meal_optimizer_method" {
  rest_api_id   = aws_api_gateway_rest_api.nutrition_api.id
  resource_id   = aws_api_gateway_resource.meal_optimizer_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "meal_optimizer_integration" {
  rest_api_id = aws_api_gateway_rest_api.nutrition_api.id
  resource_id = aws_api_gateway_resource.meal_optimizer_resource.id
  http_method = aws_api_gateway_method.meal_optimizer_method.http_method

  integration_http_method = "POST"
  type                   = "HTTP_PROXY"
  uri                    = "http://${aws_lb.nutria_alb.dns_name}/optimize"

  connection_type = "INTERNET"
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "compute_targets_api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compute_targets.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.nutrition_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "nutrition_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.compute_targets_integration,
    aws_api_gateway_integration.meal_optimizer_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.nutrition_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.compute_targets_resource.id,
      aws_api_gateway_method.compute_targets_method.id,
      aws_api_gateway_integration.compute_targets_integration.id,
      aws_api_gateway_resource.meal_optimizer_resource.id,
      aws_api_gateway_method.meal_optimizer_method.id,
      aws_api_gateway_integration.meal_optimizer_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "nutrition_api_stage" {
  deployment_id = aws_api_gateway_deployment.nutrition_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.nutrition_api.id
  stage_name    = var.environment
}

# Outputs
output "ecr_repository_url" {
  description = "ECR repository URL for meal optimizer"
  value       = aws_ecr_repository.meal_optimizer.repository_url
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.nutrition_data.id
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = "https://${aws_api_gateway_rest_api.nutrition_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
}

output "targets_endpoint" {
  description = "Endpoint for nutrition targets (Lambda)"
  value       = "https://${aws_api_gateway_rest_api.nutrition_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}/targets"
}

output "optimizer_endpoint" {
  description = "Endpoint for meal optimizer (Fargate)"
  value       = "https://${aws_api_gateway_rest_api.nutrition_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}/optimize"
}

output "fargate_alb_url" {
  description = "Direct Fargate ALB URL"
  value       = "http://${aws_lb.nutria_alb.dns_name}"
}

output "deployment_summary" {
  description = "Deployment summary"
  value = {
    project_name      = var.project_name
    environment       = var.environment
    region           = var.aws_region
    bucket_name      = aws_s3_bucket.nutrition_data.id
    api_url          = "https://${aws_api_gateway_rest_api.nutrition_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
    targets_service  = "Lambda"
    optimizer_service = "Fargate"
    ecs_cluster      = aws_ecs_cluster.nutria_cluster.name
  }
}