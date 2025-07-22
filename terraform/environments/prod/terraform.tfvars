# Production environment configuration
project_name = "nutria"
environment  = "prod"
aws_region   = "eu-west-1"

# Network Configuration
vpc_cidr                 = "10.2.0.0/16"
availability_zones_count = 3

# ECS Configuration
fargate_cpu    = "2048"
fargate_memory = "4096"
app_count      = 3

# Auto Scaling
ecs_autoscale_min_instances = 3
ecs_autoscale_max_instances = 10

# Lambda Configuration
lambda_timeout = 60
lambda_memory  = 1024

# Data Configuration
csv_file_path = "/home/torel/IdeaProjects/NutriaIngestionAndSolver/data_prep/data/products_names_with_macro_nutriments(in).csv"