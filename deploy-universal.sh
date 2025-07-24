#!/bin/bash

# Universal Fargate Deployment Script
# Usage: ./deploy-universal.sh <Dockerfile> [service-prefix]
# Example: ./deploy-universal.sh Dockerfile.optimized2 meal-optimizer

set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-eu-west-1}"
ECS_CLUSTER_NAME="nutria-dev-cluster"
IMAGE_TAG="${IMAGE_TAG:-latest}"
BUILD_CONTEXT="."
CPU="${CPU:-1024}"
MEMORY="${MEMORY:-2048}"
PORT="${PORT:-8080}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

show_usage() {
    echo "Usage: $0 <Dockerfile> [service-prefix]"
    echo ""
    echo "Arguments:"
    echo "  Dockerfile     - Name of the Dockerfile to use (e.g., Dockerfile.optimized2)"
    echo "  service-prefix - Optional prefix for service name (default: nutria-app)"
    echo ""
    echo "Examples:"
    echo "  $0 Dockerfile.optimized2"
    echo "  $0 Dockerfile.micro micro-app"
    echo "  $0 Dockerfile test-app"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION - AWS region (default: eu-west-1)"
    echo "  IMAGE_TAG  - Docker image tag (default: latest)"
    echo "  CPU        - Fargate CPU units (default: 1024)"
    echo "  MEMORY     - Fargate memory MB (default: 2048)"
    echo "  PORT       - Container port (default: 8080)"
}

generate_random_suffix() {
    # Generate a random 6-character suffix using lowercase letters and numbers
    cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1
}

check_dependencies() {
    log_step "Checking dependencies..."
    
    local deps=("aws" "docker" "jq")
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
    
    log_info "All dependencies satisfied."
}

auto_detect_s3_bucket() {
    log_step "Auto-detecting S3 bucket..."
    
    # Find the active nutrition data bucket
    S3_BUCKET_NAME=$(aws s3 ls | grep "nutria.*nutrition-data" | tail -1 | awk '{print $3}')
    
    if [ -z "$S3_BUCKET_NAME" ]; then
        log_error "Could not find S3 nutrition data bucket."
        exit 1
    fi
    
    # Check if CSV file exists in bucket
    CSV_FILE_KEY="data/products_nutrition.csv"
    if aws s3 ls "s3://$S3_BUCKET_NAME/$CSV_FILE_KEY" &> /dev/null; then
        log_info "Found S3 bucket: $S3_BUCKET_NAME"
        log_info "Found CSV file: $CSV_FILE_KEY"
    else
        log_warning "CSV file not found at $CSV_FILE_KEY, using default path"
    fi
}

create_ecr_repository() {
    log_step "Creating ECR repository..."
    
    # Check if repository already exists
    if aws ecr describe-repositories --repository-names "$ECR_REPOSITORY_NAME" --region "$AWS_REGION" &> /dev/null; then
        log_info "ECR repository $ECR_REPOSITORY_NAME already exists."
    else
        aws ecr create-repository \
            --repository-name "$ECR_REPOSITORY_NAME" \
            --region "$AWS_REGION" > /dev/null
        
        log_info "Created ECR repository: $ECR_REPOSITORY_NAME"
    fi
    
    # Get account ID and construct ECR URL
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REPOSITORY_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"
    log_info "ECR Repository URL: $ECR_REPOSITORY_URL"
}

build_docker_image() {
    log_step "Building Docker image..."
    
    # Check if Dockerfile exists
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "Dockerfile not found at $DOCKERFILE_PATH"
        exit 1
    fi
    
    log_info "Using Dockerfile: $DOCKERFILE_PATH"
    
    # Handle app.py copying if needed (for Dockerfiles that expect it in root)
    NEEDS_APP_COPY=false
    if grep -q "COPY.*app\.py" "$DOCKERFILE_PATH"; then
        if [ ! -f "app.py" ] && [ -f "fargate/app.py" ]; then
            cp fargate/app.py . 2>/dev/null || true
            NEEDS_APP_COPY=true
            log_info "Temporarily copied app.py to root for Docker build context"
        fi
    fi
    
    # Build the image
    docker build -t "$ECR_REPOSITORY_NAME:$IMAGE_TAG" -f "$DOCKERFILE_PATH" "$BUILD_CONTEXT"
    
    # Clean up copied app.py if we created it
    if [ "$NEEDS_APP_COPY" = true ]; then
        rm -f app.py 2>/dev/null || true
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Docker image built successfully."
    else
        log_error "Failed to build Docker image."
        exit 1
    fi
}

push_to_ecr() {
    log_step "Pushing image to ECR..."
    
    # Authenticate with ECR
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$ECR_REPOSITORY_URL"
    
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

create_task_definition() {
    log_step "Creating ECS task definition..."
    
    # Create CloudWatch log group
    aws logs create-log-group \
        --log-group-name "/ecs/$TASK_DEFINITION_NAME" \
        --region "$AWS_REGION" 2>/dev/null || true
    
    # Create task definition
    aws ecs register-task-definition \
        --family "$TASK_DEFINITION_NAME" \
        --network-mode "awsvpc" \
        --requires-compatibilities "FARGATE" \
        --cpu "$CPU" \
        --memory "$MEMORY" \
        --execution-role-arn "arn:aws:iam::$ACCOUNT_ID:role/nutria-dev-ecs-execution-role" \
        --task-role-arn "arn:aws:iam::$ACCOUNT_ID:role/nutria-dev-ecs-task-role" \
        --container-definitions "[
            {
                \"name\": \"$CONTAINER_NAME\",
                \"image\": \"$ECR_REPOSITORY_URL:$IMAGE_TAG\",
                \"essential\": true,
                \"portMappings\": [
                    {
                        \"containerPort\": $PORT,
                        \"hostPort\": $PORT,
                        \"protocol\": \"tcp\"
                    }
                ],
                \"environment\": [
                    {
                        \"name\": \"PORT\",
                        \"value\": \"$PORT\"
                    },
                    {
                        \"name\": \"ENVIRONMENT\",
                        \"value\": \"dev\"
                    },
                    {
                        \"name\": \"S3_BUCKET_NAME\",
                        \"value\": \"$S3_BUCKET_NAME\"
                    },
                    {
                        \"name\": \"CSV_FILE_KEY\",
                        \"value\": \"$CSV_FILE_KEY\"
                    }
                ],
                \"logConfiguration\": {
                    \"logDriver\": \"awslogs\",
                    \"options\": {
                        \"awslogs-group\": \"/ecs/$TASK_DEFINITION_NAME\",
                        \"awslogs-region\": \"$AWS_REGION\",
                        \"awslogs-stream-prefix\": \"ecs\"
                    }
                },
                \"healthCheck\": {
                    \"command\": [\"CMD-SHELL\", \"curl -f http://localhost:$PORT/health || exit 1\"],
                    \"interval\": 30,
                    \"timeout\": 5,
                    \"retries\": 3,
                    \"startPeriod\": 60
                }
            }
        ]" \
        --region "$AWS_REGION" > /dev/null
    
    log_info "Task definition created: $TASK_DEFINITION_NAME"
}

create_ecs_service() {
    log_step "Creating ECS service..."
    
    # Get subnet and security group IDs
    VPC_ID="vpc-0ae160c727ceec708"
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=nutria-dev-public-subnet-*" "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[0:2].SubnetId' \
        --output text \
        --region "$AWS_REGION")
    
    SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Name,Values=nutria-dev-fargate-sg" "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        --region "$AWS_REGION")
    
    # Convert space-separated subnet IDs to JSON array format
    SUBNET_ARRAY=$(echo $SUBNET_IDS | tr ' ' '\n' | sed 's/^/"/' | sed 's/$/"/' | tr '\n' ',' | sed 's/,$//')
    
    # Create ECS service
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
    
    log_info "ECS service created: $SERVICE_NAME"
}

wait_for_service() {
    log_step "Waiting for service to stabilize..."
    
    aws ecs wait services-stable \
        --cluster "$ECS_CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION"
    
    log_info "Service is stable and running."
}

get_service_info() {
    log_step "Getting service information..."
    
    # Get the running task ARN
    TASK_ARN=$(aws ecs list-tasks \
        --cluster "$ECS_CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
        --query 'taskArns[0]' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
        # Get the ENI ID
        ENI_ID=$(aws ecs describe-tasks \
            --cluster "$ECS_CLUSTER_NAME" \
            --tasks "$TASK_ARN" \
            --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
            --output text \
            --region "$AWS_REGION" 2>/dev/null || echo "")
        
        if [ -n "$ENI_ID" ] && [ "$ENI_ID" != "None" ]; then
            # Get the public IP
            PUBLIC_IP=$(aws ec2 describe-network-interfaces \
                --network-interface-ids "$ENI_ID" \
                --query 'NetworkInterfaces[0].Association.PublicIp' \
                --output text \
                --region "$AWS_REGION" 2>/dev/null || echo "")
            
            if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
                log_info "Service is running at: http://$PUBLIC_IP:$PORT"
                log_info "Health check: curl http://$PUBLIC_IP:$PORT/health"
                
                # Test the health endpoint
                sleep 5
                log_info "Testing health endpoint..."
                if curl -f -s "http://$PUBLIC_IP:$PORT/health" > /dev/null 2>&1; then
                    log_info "✅ Health check passed!"
                else
                    log_warning "⚠️  Health check failed - service might still be starting"
                fi
            else
                log_warning "Could not get public IP for service"
            fi
        else
            log_warning "Could not get network interface ID"
        fi
    else
        log_warning "No running tasks found for service"
    fi
}

show_summary() {
    echo ""
    echo "🎉 Deployment Summary:"
    echo "===================="
    echo "📁 Dockerfile: $DOCKERFILE_PATH"
    echo "🏷️  ECR Repository: $ECR_REPOSITORY_NAME"
    echo "🐳 Image: $ECR_REPOSITORY_URL:$IMAGE_TAG"
    echo "⚙️  ECS Service: $SERVICE_NAME"
    echo "📋 Task Definition: $TASK_DEFINITION_NAME"
    echo "💾 S3 Bucket: $S3_BUCKET_NAME"
    echo "🔧 CPU/Memory: ${CPU}/${MEMORY}"
    echo "🌐 Port: $PORT"
    echo ""
    if [ -n "${PUBLIC_IP:-}" ] && [ "$PUBLIC_IP" != "None" ]; then
        echo "🌍 Service URL: http://$PUBLIC_IP:$PORT"
        echo "❤️  Health Check: http://$PUBLIC_IP:$PORT/health"
    fi
    echo ""
}

# Main execution
main() {
    # Parse arguments
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    DOCKERFILE_NAME="$1"
    SERVICE_PREFIX="${2:-nutria-app}"
    DOCKERFILE_PATH="./fargate/$DOCKERFILE_NAME"
    
    # Check if Dockerfile exists
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "Dockerfile not found: $DOCKERFILE_PATH"
        log_error "Available Dockerfiles in fargate/:"
        ls -1 fargate/Dockerfile* 2>/dev/null || echo "  No Dockerfiles found"
        exit 1
    fi
    
    # Generate random names
    RANDOM_SUFFIX=$(generate_random_suffix)
    ECR_REPOSITORY_NAME="nutria/${SERVICE_PREFIX}-${RANDOM_SUFFIX}"
    SERVICE_NAME="${SERVICE_PREFIX}-${RANDOM_SUFFIX}"
    TASK_DEFINITION_NAME="${SERVICE_PREFIX}-${RANDOM_SUFFIX}"
    CONTAINER_NAME="${SERVICE_PREFIX}-container"
    
    log_info "🚀 Starting universal Fargate deployment..."
    log_info "📁 Dockerfile: $DOCKERFILE_PATH"
    log_info "🏷️  Random suffix: $RANDOM_SUFFIX"
    log_info "🐳 ECR Repository: $ECR_REPOSITORY_NAME"
    log_info "⚙️  Service Name: $SERVICE_NAME"
    echo ""
    
    # Execute deployment steps
    check_dependencies
    auto_detect_s3_bucket
    create_ecr_repository
    build_docker_image
    push_to_ecr
    create_task_definition
    create_ecs_service
    wait_for_service
    get_service_info
    show_summary
    
    log_info "🎉 Deployment completed successfully!"
}

# Run main function with all arguments
main "$@"