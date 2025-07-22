# ECR Repository
resource "aws_ecr_repository" "meal_optimizer" {
  name = "${var.project_name}/meal-optimizer"

  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cluster"
    }
  )
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${local.name_prefix}-meal-optimizer"
  retention_in_days = 7

  tags = local.common_tags
}

# Task Definition
resource "aws_ecs_task_definition" "meal_optimizer" {
  family                   = "${local.name_prefix}-meal-optimizer"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "meal-optimizer"
      image = "${aws_ecr_repository.meal_optimizer.repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "S3_BUCKET_NAME"
          value = module.s3.bucket_name
        },
        {
          name  = "CSV_FILE_KEY"
          value = module.s3.csv_object_key
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}

# ECS Service
resource "aws_ecs_service" "meal_optimizer" {
  name            = "${local.name_prefix}-meal-optimizer"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.meal_optimizer.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnet_ids
    security_groups  = [aws_security_group.fargate_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.meal_optimizer.arn
    container_name   = "meal-optimizer"
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.main,
    aws_iam_role_policy.ecs_task_s3_policy
  ]

  tags = local.common_tags
}