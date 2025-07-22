# Development environment configuration
project_name = "nutria"
environment  = "dev"
aws_region   = "eu-west-1"

# Network Configuration
vpc_cidr                 = "10.0.0.0/16"
availability_zones_count = 2

# ECS Configuration
fargate_cpu    = "512"
fargate_memory = "1024"
app_count      = 1

# Auto Scaling
ecs_autoscale_min_instances = 1
ecs_autoscale_max_instances = 2

# Lambda Configuration
lambda_timeout = 30
lambda_memory  = 256

# Data Configuration
csv_file_path = "/home/torel/IdeaProjects/NutriaIngestionAndSolver/data_prep/data/products_names_with_macro_nutriments(in).csv"