#!/bin/bash
# fix_and_test.sh - Fix issues and test properly

set -e

echo "🔧 Fixing and testing Nutria deployment..."

# Get endpoints
API_URL=$(terraform output -raw api_gateway_url)
TARGETS_ENDPOINT=$(terraform output -raw targets_endpoint)
OPTIMIZER_ENDPOINT=$(terraform output -raw optimizer_endpoint)

echo "🌐 Your endpoints:"
echo "   Targets: $TARGETS_ENDPOINT"
echo "   Optimizer: $OPTIMIZER_ENDPOINT"

# Test 1: Fix and test targets (Lambda) with correct JSON
echo ""
echo "🎯 Test 1: Testing targets endpoint (Lambda)..."

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
echo "$TARGETS_RESPONSE" | jq . 2>/dev/null || echo "$TARGETS_RESPONSE"

# Extract target array for optimizer test
TARGET_ARRAY=$(echo "$TARGETS_RESPONSE" | jq -r '.target_array // [2000, 600, 80, 200]' 2>/dev/null || echo '[2000, 600, 80, 200]')

# Test 2: Check if Fargate service is running
echo ""
echo "🚀 Test 2: Checking Fargate service status..."

# Get ECS cluster and service info
CLUSTER_NAME=$(terraform output -json deployment_summary | jq -r '.ecs_cluster' 2>/dev/null)
SERVICE_NAME="nutria-meal-optimizer-service"

if [ -n "$CLUSTER_NAME" ] && [ "$CLUSTER_NAME" != "null" ]; then
    echo "Checking ECS service: $SERVICE_NAME in cluster: $CLUSTER_NAME"

    # Check service status
    SERVICE_STATUS=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region eu-west-1 \
        --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
        --output json 2>/dev/null || echo '{"error": "failed"}')

    echo "Service Status: $SERVICE_STATUS"

    RUNNING_COUNT=$(echo "$SERVICE_STATUS" | jq -r '.Running // 0')
    DESIRED_COUNT=$(echo "$SERVICE_STATUS" | jq -r '.Desired // 0')

    echo "Running tasks: $RUNNING_COUNT, Desired: $DESIRED_COUNT"

    if [ "$RUNNING_COUNT" = "0" ]; then
        echo "⚠️  No tasks running. Starting service..."

        # Scale up the service
        aws ecs update-service \
            --cluster "$CLUSTER_NAME" \
            --service "$SERVICE_NAME" \
            --desired-count 1 \
            --region eu-west-1 \
            --no-cli-pager

        echo "⏳ Waiting for service to start (this may take 2-3 minutes)..."

        # Wait a bit for the service to start
        sleep 30

        # Check again
        SERVICE_STATUS=$(aws ecs describe-services \
            --cluster "$CLUSTER_NAME" \
            --services "$SERVICE_NAME" \
            --region eu-west-1 \
            --query 'services[0].{Running:runningCount}' \
            --output json)

        RUNNING_COUNT=$(echo "$SERVICE_STATUS" | jq -r '.Running // 0')
        echo "Running tasks after scaling: $RUNNING_COUNT"
    fi
else
    echo "⚠️  Could not get cluster information"
fi

# Test 3: Check ALB health
echo ""
echo "🏥 Test 3: Checking ALB health..."

ALB_URL=$(terraform output -raw fargate_alb_url 2>/dev/null || echo "")

if [ -n "$ALB_URL" ]; then
    echo "Testing ALB health: $ALB_URL/health"

    HEALTH_RESPONSE=$(curl -s -m 10 "$ALB_URL/health" 2>/dev/null || echo '{"error": "timeout"}')
    echo "Health Response: $HEALTH_RESPONSE"

    if echo "$HEALTH_RESPONSE" | jq -e '.status' > /dev/null 2>&1; then
        echo "✅ ALB health check passed"
    else
        echo "❌ ALB health check failed"
        echo "This usually means:"
        echo "   1. Fargate task is not running"
        echo "   2. Health check is failing"
        echo "   3. Security group blocking traffic"
    fi
else
    echo "⚠️  Could not get ALB URL"
fi

# Test 4: Test optimizer with proper error handling
echo ""
echo "🍽️  Test 4: Testing optimizer endpoint..."

echo "Using target array: $TARGET_ARRAY"

OPTIMIZER_RESPONSE=$(curl -s -m 30 -X POST "$OPTIMIZER_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"target_array\": $TARGET_ARRAY
    },
    \"meal_fraction\": 0.3,
    \"solveur\": \"hybride\",
    \"sample_size\": 500
  }" 2>/dev/null || echo '{"error": "request_failed"}')

echo "Optimizer Response:"
echo "$OPTIMIZER_RESPONSE" | jq . 2>/dev/null || echo "$OPTIMIZER_RESPONSE"

# Check if optimization worked
if echo "$OPTIMIZER_RESPONSE" | jq -e '.products_used' > /dev/null 2>&1; then
    PRODUCTS_USED=$(echo "$OPTIMIZER_RESPONSE" | jq -r '.products_used')
    SOLVER=$(echo "$OPTIMIZER_RESPONSE" | jq -r '.solver')
    echo "✅ Optimization successful!"
    echo "   Products used: $PRODUCTS_USED"
    echo "   Solver: $SOLVER"
else
    echo "❌ Optimization failed"

    # Try direct ALB access if API Gateway fails
    if [ -n "$ALB_URL" ]; then
        echo ""
        echo "🔄 Trying direct ALB access..."

        DIRECT_RESPONSE=$(curl -s -m 30 -X POST "$ALB_URL/optimize" \
          -H "Content-Type: application/json" \
          -d "{
            \"user\": {
              \"target_array\": $TARGET_ARRAY
            },
            \"meal_fraction\": 0.3,
            \"solveur\": \"hybride\",
            \"sample_size\": 500
          }" 2>/dev/null || echo '{"error": "direct_failed"}')

        echo "Direct ALB Response:"
        echo "$DIRECT_RESPONSE" | jq . 2>/dev/null || echo "$DIRECT_RESPONSE"
    fi
fi

# Test 5: Diagnostics
echo ""
echo "🔍 Test 5: Diagnostics..."

# Check recent ECS task logs
if [ -n "$CLUSTER_NAME" ]; then
    echo "Checking recent ECS logs..."

    # Get recent log events
    aws logs tail "/ecs/nutria-meal-optimizer" \
        --since 10m \
        --region eu-west-1 \
        --max-items 5 2>/dev/null || echo "No recent logs found"
fi

echo ""
echo "📊 Summary:"
echo "==========="

if echo "$TARGETS_RESPONSE" | jq -e '.calculations.bmr' > /dev/null 2>&1; then
    echo "✅ Targets (Lambda): Working"
else
    echo "❌ Targets (Lambda): Failed"
fi

if echo "$OPTIMIZER_RESPONSE" | jq -e '.products_used' > /dev/null 2>&1; then
    echo "✅ Optimizer (Fargate): Working"
elif echo "$DIRECT_RESPONSE" | jq -e '.products_used' > /dev/null 2>&1; then
    echo "✅ Optimizer (Direct ALB): Working"
    echo "⚠️  API Gateway integration may need fixing"
else
    echo "❌ Optimizer (Fargate): Failed"
    echo ""
    echo "🛠️  Troubleshooting steps:"
    echo "1. Check if ECS service is running:"
    echo "   aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region eu-west-1"
    echo ""
    echo "2. Check container logs:"
    echo "   aws logs tail '/ecs/nutria-meal-optimizer' --follow --region eu-west-1"
    echo ""
    echo "3. Force restart service:"
    echo "   aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment --region eu-west-1"
fi