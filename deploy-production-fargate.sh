#!/bin/bash

# Deploy Production Fargate App to ECR - Complete Workflow Script
# This script builds the production app.py using Dockerfile.optimized2, pushes it to ECR, and optionally creates ECS service

set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-eu-west-1}"
ECR_REPOSITORY_NAME="nutria/meal-optimizer-v2"
ECS_CLUSTER_NAME="nutria-dev-cluster"
DOCKERFILE_PATH="./fargate/Dockerfile.optimized2"
IMAGE_TAG="${IMAGE_TAG:-latest}"
BUILD_CONTEXT="."
DEPLOY_NEW_SERVICE="${DEPLOY_NEW_SERVICE:-false}"
SERVICE_NAME="nutria-meal-optimizer-v2"
TASK_DEFINITION_NAME="nutria-meal-optimizer-v2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_dependencies() {
    log_info "Checking required dependencies..."
    
    local deps=("aws" "docker")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep is not installed. Please install it first."
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    log_info "All dependencies are satisfied."
}

get_ecr_repository_url() {
    log_info "Getting ECR repository URL..."
    
    # Get account ID and construct ECR URL
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    if [ -z "$ACCOUNT_ID" ]; then
        log_error "Could not get AWS account ID."
        exit 1
    fi
    
    ECR_REPOSITORY_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"
    log_info "ECR Repository URL: $ECR_REPOSITORY_URL"
}

build_docker_image() {
    log_info "Building production Docker image with Dockerfile.optimized2..."
    
    # Check if Dockerfile exists
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "Dockerfile not found at $DOCKERFILE_PATH"
        exit 1
    fi
    
    # Build the image (need to copy app.py to root temporarily for Docker context)
    cp fargate/app.py . 2>/dev/null || true
    docker build -t "$ECR_REPOSITORY_NAME:$IMAGE_TAG" -f "$DOCKERFILE_PATH" "$BUILD_CONTEXT"
    rm -f app.py 2>/dev/null || true
    
    if [ $? -eq 0 ]; then
        log_info "Docker image built successfully."
    else
        log_error "Failed to build Docker image."
        exit 1
    fi
}

push_to_ecr() {
    log_info "Pushing image to ECR..."
    
    # Get ECR login token
    log_info "Authenticating with ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REPOSITORY_URL"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to authenticate with ECR."
        exit 1
    fi
    
    # Tag the image
    docker tag "$ECR_REPOSITORY_NAME:$IMAGE_TAG" "$ECR_REPOSITORY_URL:$IMAGE_TAG"
    
    # Push the image
    docker push "$ECR_REPOSITORY_URL:$IMAGE_TAG"
    
    if [ $? -eq 0 ]; then
        log_info "Image pushed successfully to ECR."
    else
        log_error "Failed to push image to ECR."
        exit 1
    fi
}

create_ecs_task_definition() {
    if [ "$DEPLOY_NEW_SERVICE" != "true" ]; then
        return
    fi
    
    log_info "Creating ECS task definition..."
    
    # Create CloudWatch log group first
    aws logs create-log-group --log-group-name "/ecs/$TASK_DEFINITION_NAME" --region "$AWS_REGION" 2>/dev/null || true
    
    # Create task definition
    aws ecs register-task-definition \
      --family "$TASK_DEFINITION_NAME" \
      --network-mode "awsvpc" \
      --requires-compatibilities "FARGATE" \
      --cpu "1024" \
      --memory "2048" \
      --execution-role-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/nutria-dev-ecs-execution-role" \
      --task-role-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/nutria-dev-ecs-task-role" \
      --container-definitions '[
        {
          "name": "meal-optimizer-v2",
          "image": "'$ECR_REPOSITORY_URL:$IMAGE_TAG'",
          "essential": true,
          "portMappings": [
            {
              "containerPort": 8080,
              "hostPort": 8080,
              "protocol": "tcp"
            }
          ],
          "environment": [
            {
              "name": "PORT",
              "value": "8080"
            },
            {
              "name": "ENVIRONMENT",
              "value": "dev"
            },
            {
              "name": "S3_BUCKET_NAME",
              "value": "nutria-dev-nutrition-data-6fea6c1a0dce3680"
            },
            {
              "name": "CSV_FILE_KEY",
              "value": "data/products_nutrition.csv"
            }
          ],
          "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
              "awslogs-group": "/ecs/'$TASK_DEFINITION_NAME'",
              "awslogs-region": "'$AWS_REGION'",
              "awslogs-stream-prefix": "ecs"
            }
          },
          "healthCheck": {
            "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
            "interval": 30,
            "timeout": 5,
            "retries": 3,
            "startPeriod": 60
          }
        }
      ]' \
      --region "$AWS_REGION" > /dev/null
    
    log_info "Task definition created successfully."
}

create_ecs_service() {
    if [ "$DEPLOY_NEW_SERVICE" != "true" ]; then
        return
    fi
    
    log_info "Creating ECS service..."
    
    # Get subnet and security group IDs from the correct VPC
    VPC_ID="vpc-0ae160c727ceec708"
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=nutria-dev-public-subnet-*" "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0:2].SubnetId' --output text --region "$AWS_REGION")
    SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=nutria-dev-fargate-sg" "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text --region "$AWS_REGION")
    
    # Convert space-separated subnet IDs to JSON array format
    SUBNET_ARRAY=$(echo $SUBNET_IDS | tr ' ' '\n' | sed 's/^/"/' | sed 's/$/"/' | tr '\n' ',' | sed 's/,$//')
    
    aws ecs create-service \
      --cluster "$ECS_CLUSTER_NAME" \
      --service-name "$SERVICE_NAME" \
      --task-definition "$TASK_DEFINITION_NAME:1" \
      --desired-count 1 \
      --launch-type "FARGATE" \
      --network-configuration "{
        \"awsvpcConfiguration\": {
          \"subnets\": [$SUBNET_ARRAY],
          \"securityGroups\": [\"$SECURITY_GROUP_ID\"],
          \"assignPublicIp\": \"ENABLED\"
        }
      }" \
      --region "$AWS_REGION" > /dev/null
    
    log_info "ECS service created successfully."
    
    # Wait for service to stabilize
    log_info "Waiting for service to stabilize..."
    aws ecs wait services-stable --cluster "$ECS_CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION"
    
    log_info "Service is now stable and running."
}

get_service_ip() {
    if [ "$DEPLOY_NEW_SERVICE" != "true" ]; then
        return
    fi
    
    log_info "Getting service public IP..."
    
    # Get the running task ARN
    TASK_ARN=$(aws ecs list-tasks \
        --cluster "$ECS_CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
        --query 'taskArns[0]' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
        log_warning "No running tasks found for service"
        return
    fi
    
    # Get the ENI ID
    ENI_ID=$(aws ecs describe-tasks \
        --cluster "$ECS_CLUSTER_NAME" \
        --tasks "$TASK_ARN" \
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -z "$ENI_ID" ] || [ "$ENI_ID" = "None" ]; then
        log_warning "Could not get network interface ID"
        return
    fi
    
    # Get the public IP
    PUBLIC_IP=$(aws ec2 describe-network-interfaces \
        --network-interface-ids "$ENI_ID" \
        --query 'NetworkInterfaces[0].Association.PublicIp' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
        log_info "Production service is running at: http://$PUBLIC_IP:8080"
        log_info "Health check: curl http://$PUBLIC_IP:8080/health"
        log_info "Test optimize endpoint: curl -X POST http://$PUBLIC_IP:8080/ -H 'Content-Type: application/json' -d '{...}'"
    else
        log_warning "Could not get public IP for service"
    fi
}

# Main execution
main() {
    log_info "Starting production Fargate deployment..."
    log_info "Region: $AWS_REGION"
    log_info "Image tag: $IMAGE_TAG"
    log_info "Dockerfile: $DOCKERFILE_PATH"
    log_info "ECR Repository: $ECR_REPOSITORY_NAME"
    
    if [ "$DEPLOY_NEW_SERVICE" = "true" ]; then
        log_info "ECS service deployment: ENABLED"
    else
        log_info "ECS service deployment: DISABLED (ECR-only mode)"
    fi
    
    check_dependencies
    get_ecr_repository_url
    build_docker_image
    push_to_ecr
    create_ecs_task_definition
    create_ecs_service
    get_service_ip
    
    log_info "Deployment completed successfully!"
    if [ "$DEPLOY_NEW_SERVICE" = "true" ]; then
        log_info "Production meal optimizer v2 is now running and ready!"
    else
        log_info "Production image is now available in ECR: $ECR_REPOSITORY_URL:$IMAGE_TAG"
    fi
}

# Run main function
main "$@"