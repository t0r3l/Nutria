#!/bin/bash
# deploy.sh - Hybrid deployment for Nutria nutrition project
# Deploys targets Lambda with layer + meal optimizer with container

set -e

echo "🚀 Starting Nutria hybrid deployment..."
echo "   📦 Targets Lambda: Layer-based (lightweight)"
echo "   🐳 Meal Optimizer: Container-based (full dependencies)"

# Variables
PROJECT_NAME="nutria"
ENVIRONMENT="dev"
AWS_REGION="eu-west-3"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Check prerequisites
echo "🔍 Checking prerequisites..."

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install and configure AWS CLI."
    exit 1
fi

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    print_error "Docker not found. Please install Docker."
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker daemon not running. Please start Docker."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform not found. Please install Terraform."
    exit 1
fi

print_step "Prerequisites check passed"

# Step 2: Build layers (targets only)
echo "📦 Building layers for targets Lambda..."

if [ ! -f "./scripts/build.sh" ]; then
    print_error "./scripts/build.sh not found. Please run it first."
    exit 1
fi

# Check if layer already exists
if [ ! -f "layers/targets_layer.zip" ]; then
    print_warning "Targets layer not found. Building it now..."
    chmod +x ./scripts/build.sh
    ././scripts/build.sh
fi

print_step "Targets layer ready"

# Step 3: Verify Lambda function files exist
echo "📋 Checking Lambda function files..."

if [ ! -f "lambda_functions/targets/lambda_function.py" ]; then
    print_error "lambda_functions/targets/lambda_function.py not found"
    exit 1
fi

if [ ! -f "lambda_functions/meal_optimizer/lambda_function.py" ]; then
    print_error "lambda_functions/meal_optimizer/lambda_function.py not found"
    exit 1
fi

if [ ! -f "lambda_functions/meal_optimizer/Dockerfile" ]; then
    print_error "lambda_functions/meal_optimizer/Dockerfile not found"
    exit 1
fi

print_step "Lambda function files verified"

# Step 4: Check CSV data file
CSV_PATH="/home/torel/IdeaProjects/NutriaIngestionAndSolver/data_prep/data/products_names_with_macro_nutriments(in).csv"
if [ ! -f "$CSV_PATH" ]; then
    print_error "CSV data file not found at: $CSV_PATH"
    print_warning "Please check the path in terraform.tfvars"
    exit 1
fi

print_step "CSV data file verified"

# Step 5: Deploy infrastructure with Terraform
echo "🏗️  Deploying infrastructure with Terraform..."

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "   Initializing Terraform..."
    terraform init
fi

# Plan deployment
echo "   Planning deployment..."
terraform plan \
    -var="project_name=$PROJECT_NAME" \
    -var="environment=$ENVIRONMENT" \
    -var="aws_region=$AWS_REGION"

# Apply deployment
echo "   Applying deployment..."
terraform apply \
    -var="project_name=$PROJECT_NAME" \
    -var="environment=$ENVIRONMENT" \
    -var="aws_region=$AWS_REGION" \
    -auto-approve

print_step "Infrastructure deployed"

# Step 6: Get ECR repository URL from Terraform output
echo "🔗 Getting ECR repository information..."

ECR_URL=$(terraform output -raw ecr_repository_url)
if [ -z "$ECR_URL" ]; then
    print_error "Could not get ECR repository URL from Terraform output"
    exit 1
fi

echo "   ECR Repository: $ECR_URL"
print_step "ECR repository ready"

# Step 7: Build and push Docker image for meal optimizer
echo "🐳 Building and pushing meal optimizer container..."

# Navigate to meal optimizer directory
cd lambda_functions/meal_optimizer

# Build Docker image
echo "   Building Docker image..."
docker build -t meal-optimizer . --no-cache

# Login to ECR
echo "   Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_URL

# Tag and push image
echo "   Tagging and pushing image..."
docker tag meal-optimizer:latest $ECR_URL:latest
docker push $ECR_URL:latest

# Return to root directory
cd ../..

print_step "Container image pushed to ECR"

# Step 8: Update Lambda function with new image
echo "🔄 Updating meal optimizer Lambda function..."

# Get function name from Terraform output
MEAL_OPTIMIZER_FUNCTION=$(terraform output -json | jq -r '.deployment_summary.value.lambdas_created[1]')

if [ "$MEAL_OPTIMIZER_FUNCTION" = "null" ] || [ -z "$MEAL_OPTIMIZER_FUNCTION" ]; then
    print_warning "Could not get meal optimizer function name from output. Trying alternative method..."
    # Alternative: construct function name
    BUCKET_SUFFIX=$(terraform output -raw s3_bucket_name | grep -o '[^-]*$')
    MEAL_OPTIMIZER_FUNCTION="${PROJECT_NAME}-meal-optimizer-${BUCKET_SUFFIX}"
fi

echo "   Updating function: $MEAL_OPTIMIZER_FUNCTION"

aws lambda update-function-code \
    --function-name "$MEAL_OPTIMIZER_FUNCTION" \
    --image-uri "$ECR_URL:latest" \
    --region $AWS_REGION

print_step "Lambda function updated with container image"

# Step 9: Wait for function to be ready
echo "⏳ Waiting for Lambda function to be ready..."
aws lambda wait function-updated \
    --function-name "$MEAL_OPTIMIZER_FUNCTION" \
    --region $AWS_REGION

print_step "Lambda function is ready"

# Step 10: Get API endpoints and show results
echo "🌐 Getting API endpoints..."

API_URL=$(terraform output -raw api_gateway_url)
TARGETS_ENDPOINT=$(terraform output -raw compute_targets_endpoint)
OPTIMIZER_ENDPOINT=$(terraform output -raw meal_optimizer_endpoint)
S3_BUCKET=$(terraform output -raw s3_bucket_name)

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📊 Deployment Summary:"
echo "   Project: $PROJECT_NAME"
echo "   Environment: $ENVIRONMENT"
echo "   Region: $AWS_REGION"
echo "   S3 Bucket: $S3_BUCKET"
echo ""
echo "🌐 API Endpoints:"
echo "   Base URL: $API_URL"
echo "   Targets: $TARGETS_ENDPOINT"
echo "   Optimizer: $OPTIMIZER_ENDPOINT"
echo ""
echo "🏗️  Infrastructure:"
echo "   ✅ S3 bucket with CSV data uploaded"
echo "   ✅ Targets Lambda (layer-based)"
echo "   ✅ Meal Optimizer Lambda (container-based)"
echo "   ✅ API Gateway with endpoints"
echo "   ✅ IAM roles and policies"
echo "   ✅ CloudWatch log groups"
echo ""
echo "🧪 Test your APIs:"
echo ""
echo "# Test targets calculation:"
echo "curl -X POST $TARGETS_ENDPOINT \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"gender\": \"male\","
echo "    \"age\": 30,"
echo "    \"height\": 175,"
echo "    \"weight_in_kg\": 70,"
echo "    \"activity_level\": \"moderate\","
echo "    \"objectif\": \"weight loss\""
echo "  }'"
echo ""
echo "# Test meal optimization (use target_array from above response):"
echo "curl -X POST $OPTIMIZER_ENDPOINT \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"user\": {"
echo "      \"target_array\": [2000, 600, 80, 200]"
echo "    },"
echo "    \"meal_fraction\": 0.3,"
echo "    \"sample_size\": 100"
echo "  }'"
echo ""
echo "🎯 Your Nutria nutrition optimization system is ready!"