# Staging environment configuration
project_name = "nutria"
environment  = "staging"
aws_region   = "eu-west-1"

# Network Configuration
vpc_cidr                 = "10.1.0.0/16"
availability_zones_count = 2

# ECS Configuration
fargate_cpu    = "1024"
fargate_memory = "2048"
app_count      = 2

# Auto Scaling
ecs_autoscale_min_instances = 2
ecs_autoscale_max_instances = 4

# Lambda Configuration
lambda_timeout = 30
lambda_memory  = 512

# Data Configuration
csv_file_path = "/home/torel/IdeaProjects/NutriaIngestionAndSolver/data_prep/data/products_names_with_macro_nutriments(in).csv"