# Nutria Infrastructure

This directory contains the Terraform configuration for the Nutria nutrition optimization platform.

## Architecture Overview

The infrastructure includes:
- **VPC**: Custom VPC with public and private subnets across multiple AZs
- **ECS Fargate**: Containerized meal optimizer service
- **Lambda**: Compute targets function for calculating nutritional requirements
- **API Gateway**: RESTful API endpoints
- **S3**: Storage for nutrition data CSV files
- **ALB**: Application Load Balancer for ECS services
- **Auto Scaling**: CPU and memory-based scaling for ECS tasks

## Directory Structure

```
terraform/
├── modules/              # Reusable Terraform modules
│   ├── vpc/             # VPC and networking
│   └── s3/              # S3 bucket configuration
├── environments/         # Environment-specific configurations
│   ├── dev/             # Development environment
│   ├── staging/         # Staging environment
│   └── prod/            # Production environment
├── main.tf              # Main configuration
├── ecs.tf               # ECS resources
├── lambda.tf            # Lambda functions
├── api_gateway.tf       # API Gateway configuration
├── alb.tf               # Load balancer configuration
├── iam.tf               # IAM roles and policies
├── autoscaling.tf       # Auto-scaling configuration
├── variables.tf         # Variable definitions
├── outputs.tf           # Output definitions
├── locals.tf            # Local values
├── data.tf              # Data sources
├── provider.tf          # Provider configuration
└── versions.tf          # Terraform version constraints
```

## Usage

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Deploy to an Environment

For development:
```bash
terraform workspace new dev || terraform workspace select dev
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

For staging:
```bash
terraform workspace new staging || terraform workspace select staging
terraform plan -var-file=environments/staging/terraform.tfvars
terraform apply -var-file=environments/staging/terraform.tfvars
```

For production:
```bash
terraform workspace new prod || terraform workspace select prod
terraform plan -var-file=environments/prod/terraform.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars
```

### 3. Deploy Docker Image to ECR

After infrastructure is deployed:
```bash
# Get ECR repository URL
ECR_URL=$(terraform output -raw ecr_repository_url)

# Build and push Docker image
cd ../fargate
docker build -t meal-optimizer .
docker tag meal-optimizer:latest ${ECR_URL}:latest
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin ${ECR_URL}
docker push ${ECR_URL}:latest

# Update ECS service to use new image
aws ecs update-service --cluster $(terraform output -raw ecs_cluster_name) \
  --service $(terraform output -raw ecs_service_name) \
  --force-new-deployment
```

## Backend Configuration

For team collaboration, configure S3 backend:

1. Create S3 bucket and DynamoDB table for state:
```bash
aws s3api create-bucket --bucket nutria-terraform-state --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1
aws dynamodb create-table --table-name nutria-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

2. Copy backend configuration to environment:
```bash
cp environments/backend.tf.example environments/dev/backend.tf
# Edit the file to set the correct key for each environment
```

## Important Outputs

After deployment, you can get important URLs:
```bash
# API Gateway URL
terraform output api_gateway_url

# ALB URL (direct access to Fargate)
terraform output alb_url

# API Endpoints
terraform output api_endpoints
```

## Monitoring

- CloudWatch Logs: Check `/ecs/nutria-{env}-meal-optimizer` for container logs
- ECS Console: Monitor task health and scaling
- ALB Target Group: Check target health status

## Cleanup

To destroy resources in an environment:
```bash
terraform destroy -var-file=environments/dev/terraform.tfvars
```