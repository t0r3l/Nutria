#!/bin/bash

# Deploy Fargate App to ECR - Complete Workflow Script
# This script builds the Docker image, pushes it to ECR, and updates the ECS service

set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-eu-west-1}"
ECR_REPOSITORY_NAME="nutria/test-meal-optimizer"
ECS_CLUSTER_NAME=""
ECS_SERVICE_NAME=""
DOCKERFILE_PATH="./fargate/Dockerfile2"
IMAGE_TAG="${IMAGE_TAG:-latest}"
BUILD_CONTEXT="."
TERRAFORM_ENV="${TERRAFORM_ENV:-dev}"
USE_TERRAFORM="${USE_TERRAFORM:-true}"
MANUAL_ECR_URL="${MANUAL_ECR_URL:-}"
DEPLOY_TEST_SERVICE="${DEPLOY_TEST_SERVICE:-false}"
TEST_SERVICE_NAME="nutria-test-flask-app"
TEST_TASK_DEFINITION="nutria-test-flask-app"

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
    
    local deps=("aws" "docker" "terraform")
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

get_terraform_outputs() {
    if [ "$USE_TERRAFORM" != "true" ]; then
        log_info "Terraform disabled. Using manual configuration."
        
        if [ -z "$MANUAL_ECR_URL" ]; then
            # Try to get account ID and construct ECR URL
            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
            if [ -z "$ACCOUNT_ID" ]; then
                log_error "Could not get AWS account ID. Please set MANUAL_ECR_URL environment variable."
                exit 1
            fi
            ECR_REPOSITORY_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"
            log_warning "Constructed ECR URL: $ECR_REPOSITORY_URL"
            log_warning "If this is incorrect, set MANUAL_ECR_URL environment variable."
        else
            ECR_REPOSITORY_URL="$MANUAL_ECR_URL"
        fi
        
        log_info "ECR Repository URL: $ECR_REPOSITORY_URL"
        log_warning "ECS update skipped - Terraform not in use"
        return
    fi
    
    log_info "Getting Terraform outputs..."
    
    # Save current directory
    SCRIPT_DIR=$(pwd)
    
    # Check if terraform directory exists
    if [ ! -d "terraform/environments/$TERRAFORM_ENV" ]; then
        log_error "Terraform environment directory not found: terraform/environments/$TERRAFORM_ENV"
        exit 1
    fi
    
    cd "terraform/environments/$TERRAFORM_ENV"
    
    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        log_warning "Terraform not initialized in this environment. Initializing now..."
        terraform init
        if [ $? -ne 0 ]; then
            log_error "Failed to initialize Terraform."
            exit 1
        fi
    fi
    
    # Get ECR repository URL
    ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
    if [ -z "$ECR_REPOSITORY_URL" ]; then
        log_error "Could not get ECR repository URL from Terraform outputs."
        exit 1
    fi
    
    # Get ECS cluster and service names
    ECS_CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
    ECS_SERVICE_NAME=$(terraform output -raw ecs_service_name 2>/dev/null || echo "")
    
    if [ -z "$ECS_CLUSTER_NAME" ] || [ -z "$ECS_SERVICE_NAME" ]; then
        log_error "Could not get ECS cluster or service name from Terraform outputs."
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
    
    log_info "ECR Repository URL: $ECR_REPOSITORY_URL"
    log_info "ECS Cluster: $ECS_CLUSTER_NAME"
    log_info "ECS Service: $ECS_SERVICE_NAME"
}

build_docker_image() {
    log_info "Building Docker image..."
    
    # Check if Dockerfile exists
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "Dockerfile not found at $DOCKERFILE_PATH"
        exit 1
    fi
    
    # Build the image
    docker build -t "$ECR_REPOSITORY_NAME:$IMAGE_TAG" -f "$DOCKERFILE_PATH" "$BUILD_CONTEXT"
    
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

update_ecs_service() {
    if [ "$USE_TERRAFORM" != "true" ]; then
        log_warning "Skipping ECS service update - Terraform not in use"
        return
    fi
    
    log_info "Updating ECS service..."
    
    # Force new deployment
    aws ecs update-service \
        --region "$AWS_REGION" \
        --cluster "$ECS_CLUSTER_NAME" \
        --service "$ECS_SERVICE_NAME" \
        --force-new-deployment \
        --output json > /dev/null
    
    if [ $? -eq 0 ]; then
        log_info "ECS service update initiated successfully."
    else
        log_error "Failed to update ECS service."
        exit 1
    fi
}

wait_for_deployment() {
    if [ "$USE_TERRAFORM" != "true" ]; then
        log_warning "Skipping deployment wait - Terraform not in use"
        return
    fi
    
    log_info "Waiting for deployment to stabilize..."
    
    # Wait for service to stabilize (max 10 minutes)
    aws ecs wait services-stable \
        --region "$AWS_REGION" \
        --cluster "$ECS_CLUSTER_NAME" \
        --services "$ECS_SERVICE_NAME" \
        --no-cli-pager || {
        log_error "Deployment failed to stabilize within timeout period."
        exit 1
    }
    
    log_info "Deployment completed successfully!"
}

deploy_test_service() {
    if [ "$DEPLOY_TEST_SERVICE" != "true" ]; then
        return
    fi
    
    log_info "Deploying test service..."
    
    # Update task definition with new image
    CURRENT_TASK_DEF=$(aws ecs describe-task-definition \
        --task-definition "$TEST_TASK_DEFINITION" \
        --region "$AWS_REGION" \
        --query 'taskDefinition' \
        --output json)
    
    # Update the image in the task definition
    NEW_TASK_DEF=$(echo "$CURRENT_TASK_DEF" | jq --arg image "$ECR_REPOSITORY_URL:$IMAGE_TAG" \
        '.containerDefinitions[0].image = $image | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)')
    
    # Register new task definition
    NEW_TASK_ARN=$(echo "$NEW_TASK_DEF" | aws ecs register-task-definition \
        --region "$AWS_REGION" \
        --cli-input-json file:///dev/stdin \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    log_info "Registered new task definition: $NEW_TASK_ARN"
    
    # Update the service
    aws ecs update-service \
        --region "$AWS_REGION" \
        --cluster nutria-dev-cluster \
        --service "$TEST_SERVICE_NAME" \
        --task-definition "$NEW_TASK_ARN" \
        --force-new-deployment \
        --output json > /dev/null
    
    log_info "Test service update initiated successfully."
    
    # Wait for test service to stabilize
    log_info "Waiting for test service to stabilize..."
    aws ecs wait services-stable \
        --region "$AWS_REGION" \
        --cluster nutria-dev-cluster \
        --services "$TEST_SERVICE_NAME" \
        --no-cli-pager || {
        log_error "Test service deployment failed to stabilize within timeout period."
        exit 1
    }
    
    log_info "Test service deployment completed successfully!"
}

get_test_service_ip() {
    if [ "$DEPLOY_TEST_SERVICE" != "true" ]; then
        return
    fi
    
    log_info "Getting test service public IP..."
    
    # Get the running task ARN
    TASK_ARN=$(aws ecs list-tasks \
        --cluster nutria-dev-cluster \
        --service-name "$TEST_SERVICE_NAME" \
        --query 'taskArns[0]' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
        log_warning "No running tasks found for test service"
        return
    fi
    
    # Get the ENI ID
    ENI_ID=$(aws ecs describe-tasks \
        --cluster nutria-dev-cluster \
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
        log_info "Test service is running at: http://$PUBLIC_IP:8080"
        log_info "Test with: ./test-flask-api.sh http://$PUBLIC_IP:8080"
    else
        log_warning "Could not get public IP for test service"
    fi
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    if [ "$USE_TERRAFORM" != "true" ]; then
        log_warning "Skipping deployment verification - Terraform not in use"
        return
    fi
    
    # Save current directory
    CURRENT_DIR=$(pwd)
    
    # Get the ALB URL from Terraform outputs
    cd "terraform/environments/$TERRAFORM_ENV"
    ALB_URL=$(terraform output -raw alb_url 2>/dev/null || echo "")
    cd "$CURRENT_DIR"
    
    if [ -n "$ALB_URL" ]; then
        log_info "Testing health endpoint at $ALB_URL/health"
        
        # Wait a bit for the new containers to be ready
        sleep 10
        
        # Test the health endpoint
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$ALB_URL/health" || echo "000")
        
        if [ "$HTTP_STATUS" = "200" ]; then
            log_info "Health check passed! Service is running."
            log_info "ALB URL: $ALB_URL"
        else
            log_warning "Health check returned status $HTTP_STATUS. Service might still be starting up."
        fi
    else
        log_warning "Could not get ALB URL for verification."
    fi
    
    # Show running task count
    RUNNING_COUNT=$(aws ecs describe-services \
        --region "$AWS_REGION" \
        --cluster "$ECS_CLUSTER_NAME" \
        --services "$ECS_SERVICE_NAME" \
        --query 'services[0].runningCount' \
        --output text)
    
    log_info "Running tasks: $RUNNING_COUNT"
}

# Main execution
main() {
    log_info "Starting Fargate deployment to ECR..."
    log_info "Region: $AWS_REGION"
    log_info "Image tag: $IMAGE_TAG"
    log_info "Terraform environment: $TERRAFORM_ENV"
    
    if [ "$DEPLOY_TEST_SERVICE" = "true" ]; then
        log_info "Test service deployment: ENABLED"
    fi
    
    check_dependencies
    get_terraform_outputs
    build_docker_image
    push_to_ecr
    update_ecs_service
    wait_for_deployment
    deploy_test_service
    verify_deployment
    get_test_service_ip
    
    log_info "Deployment completed successfully!"
    if [ "$DEPLOY_TEST_SERVICE" = "true" ]; then
        log_info "Test Flask application is now running and ready for testing."
    else
        log_info "Your application is now running on Fargate with the latest image."
    fi
}

# Run main function
main "$@"