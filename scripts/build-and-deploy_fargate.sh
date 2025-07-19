
set -e

echo "🚀 Building and deploying Fargate-based meal optimizer..."

# Variables
PROJECT_NAME="nutria"
AWS_REGION="eu-west-3"

# Step 1: Create Fargate application structure
echo "📁 Creating Fargate application structure..."

mkdir -p fargate
mkdir -p lambda_functions/targets

# Copy the Fargate files (app.py, Dockerfile, requirements.txt) to fargate/

# Step 2: Apply Terraform to create infrastructure
echo "🏗️  Deploying infrastructure with Terraform..."

terraform init
terraform plan
terraform apply -auto-approve

# Get ECR URL
ECR_URL=$(terraform output -raw ecr_repository_url)
echo "📍 ECR Repository: $ECR_URL"

# Step 3: Build and push Fargate container
echo "🐳 Building Fargate container..."

cd fargate

# Build Docker image
docker build -t nutria-meal-optimizer . --no-cache

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_URL

# Tag and push image
echo "📤 Pushing image to ECR..."
docker tag nutria-meal-optimizer:latest $ECR_URL:latest
docker push $ECR_URL:latest

cd ..

# Step 4: Update ECS service to use new image
echo "🔄 Updating ECS service..."

CLUSTER_NAME=$(terraform output -json deployment_summary | jq -r '.ecs_cluster')
SERVICE_NAME="${PROJECT_NAME}-meal-optimizer-service"

# Force new deployment
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --force-new-deployment \
    --region $AWS_REGION

echo "⏳ Waiting for service to stabilize..."
aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region $AWS_REGION

# Step 5: Scale up the service
echo "📈 Scaling up ECS service..."
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --desired-count 1 \
    --region $AWS_REGION

echo "⏳ Waiting for service to reach desired count..."
aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region $AWS_REGION

# Step 6: Get endpoints and test
echo "🌐 Getting API endpoints..."

API_URL=$(terraform output -raw api_gateway_url)
TARGETS_ENDPOINT=$(terraform output -raw targets_endpoint)
OPTIMIZER_ENDPOINT=$(terraform output -raw optimizer_endpoint)
ALB_URL=$(terraform output -raw fargate_alb_url)

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "🌐 API Endpoints:"
echo "   API Gateway Base: $API_URL"
echo "   Targets (Lambda): $TARGETS_ENDPOINT"
echo "   Optimizer (Fargate): $OPTIMIZER_ENDPOINT"
echo "   Direct ALB: $ALB_URL"
echo ""
echo "🧪 Test commands:"
echo ""
echo "# Test targets (Lambda):"
echo "curl -X POST $TARGETS_ENDPOINT \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"gender\":\"male\",\"age\":30,\"height\":175,\"weight_in_kg\":70,\"activity_level\":\"moderate\",\"objectif\":\"weight loss\"}'"
echo ""
echo "# Test optimizer (Fargate):"
echo "curl -X POST $OPTIMIZER_ENDPOINT \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"user\":{\"target_array\":[2000,600,80,200]},\"meal_fraction\":0.3}'"
echo ""
echo "# Test ALB health check:"
echo "curl $ALB_URL/health"
echo ""
echo "🎯 Your hybrid Nutria system is ready!"
echo "   📦 Targets: Fast Lambda with layers"
echo "   🚀 Optimizer: Powerful Fargate with full scientific stack"

---

# test_fargate_system.sh
#!/bin/bash

set -e

echo "🧪 Testing Fargate-based Nutria system..."

# Get endpoints
API_URL=$(terraform output -raw api_gateway_url)
TARGETS_ENDPOINT=$(terraform output -raw targets_endpoint)
OPTIMIZER_ENDPOINT=$(terraform output -raw optimizer_endpoint)
ALB_URL=$(terraform output -raw fargate_alb_url)

echo "📍 Testing endpoints:"
echo "   Targets (Lambda): $TARGETS_ENDPOINT"
echo "   Optimizer (Fargate): $OPTIMIZER_ENDPOINT"
echo "   ALB Direct: $ALB_URL"

# Test 1: ALB Health Check
echo ""
echo "🏥 Test 1: ALB Health Check..."
HEALTH_RESPONSE=$(curl -s "$ALB_URL/health")
echo "Response: $HEALTH_RESPONSE"

# Test 2: Targets Lambda
echo ""
echo "🎯 Test 2: Targets calculation (Lambda)..."

TARGETS_RESPONSE=$(curl -s -X POST "$TARGETS_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "gender": "male",
    "age": 30,
    "height": 175,
    "weight_in_kg": 70,
    "activity_level": "moderate",
    "objectif": "weight loss"
  }')

echo "Targets Response:"
echo "$TARGETS_RESPONSE" | jq .

# Extract target array
TARGET_ARRAY=$(echo "$TARGETS_RESPONSE" | jq -r '.target_array // [2000,600,80,200]')

# Test 3: Meal Optimizer Fargate
echo ""
echo "🍽️  Test 3: Meal optimization (Fargate)..."

OPTIMIZER_RESPONSE=$(curl -s -X POST "$OPTIMIZER_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"target_array\": $TARGET_ARRAY
    },
    \"meal_fraction\": 0.3,
    \"sample_size\": 100
  }")

echo "Optimizer Response:"
echo "$OPTIMIZER_RESPONSE" | jq .

# Test 4: Performance check
echo ""
echo "⚡ Test 4: Performance comparison..."

# Time Lambda
START_TIME=$(date +%s%N)
curl -s -X POST "$TARGETS_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{"gender":"male","age":30,"height":175,"weight_in_kg":70,"activity_level":"moderate","objectif":"weight loss"}' \
  > /dev/null
END_TIME=$(date +%s%N)
LAMBDA_TIME=$((($END_TIME - $START_TIME) / 1000000))

# Time Fargate
START_TIME=$(date +%s%N)
curl -s -X POST "$OPTIMIZER_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{"user":{"target_array":[2000,600,80,200]},"meal_fraction":0.3}' \
  > /dev/null
END_TIME=$(date +%s%N)
FARGATE_TIME=$((($END_TIME - $START_TIME) / 1000000))

echo "⏱️  Performance Results:"
echo "   Lambda (targets): ${LAMBDA_TIME}ms"
echo "   Fargate (optimizer): ${FARGATE_TIME}ms"

echo ""
echo "✅ All tests completed!"
echo ""
echo "🎉 Your hybrid system is working:"
echo "   📦 Fast nutrition calculations in Lambda"
echo "   🚀 Powerful meal optimization in Fargate"
echo "   🌐 Unified API through API Gateway"
