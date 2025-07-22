#!/bin/bash
# fix_ecr_push.sh - Fix ECR push issue and complete deployment

set -e

echo "🔧 Fixing ECR push and completing deployment..."

# Step 1: Get ECR URL manually
echo "📋 Step 1: Finding ECR repository..."

# Get ECR URL from AWS directly
ECR_URL=$(aws ecr describe-repositories \
    --repository-names "nutria/meal-optimizer" \
    --region eu-west-1 \
    --query 'repositories[0].repositoryUri' \
    --output text 2>/dev/null || echo "")

if [ -z "$ECR_URL" ]; then
    echo "❌ Could not find ECR repository"
    echo "Let's check what repositories exist:"
    aws ecr describe-repositories --region eu-west-1 --query 'repositories[].repositoryName' --output table
    exit 1
fi

echo "✅ Found ECR repository: $ECR_URL"

# Step 2: Push the container image
echo ""
echo "🐳 Step 2: Pushing container to ECR..."

cd fargate

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $ECR_URL

# Tag and push
echo "Tagging image..."
docker tag nutria-meal-optimizer:latest $ECR_URL:latest

echo "Pushing image..."
docker push $ECR_URL:latest

cd ..

echo "✅ Container image pushed successfully"

# Step 3: Force restart ECS service
echo ""
echo "🔄 Step 3: Restarting ECS service with new image..."

aws ecs update-service \
    --cluster "nutria-cluster-adcd61bb0cdcd880" \
    --service "nutria-meal-optimizer-service" \
    --force-new-deployment \
    --region eu-west-1 \
    --no-cli-pager > /dev/null

echo "✅ Service restart initiated"

# Step 4: Wait for deployment
echo ""
echo "⏳ Step 4: Waiting for deployment to complete..."

echo "Waiting 1 minute for deployment to start..."
sleep 60

# Check deployment status
echo "Checking deployment status..."
DEPLOYMENT_STATUS=$(aws ecs describe-services \
    --cluster "nutria-cluster-adcd61bb0cdcd880" \
    --services "nutria-meal-optimizer-service" \
    --region eu-west-1 \
    --query 'services[0].deployments[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount}')

echo "Deployment status: $DEPLOYMENT_STATUS"

echo ""
echo "Waiting additional 2 minutes for container startup..."
sleep 120

# Step 5: Test the service
echo ""
echo "🧪 Step 5: Testing the updated service..."

# Test health endpoint
echo "Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s -m 15 "http://nutria-alb-adcd61-970243738.eu-west-1.elb.amazonaws.com/health" 2>/dev/null || echo '{"error": "timeout"}')
echo "Health response:"
echo "$HEALTH_RESPONSE" | jq . 2>/dev/null || echo "$HEALTH_RESPONSE"

# Test root endpoint
echo ""
echo "Testing root endpoint..."
ROOT_RESPONSE=$(curl -s -m 10 "http://nutria-alb-adcd61-970243738.eu-west-1.elb.amazonaws.com/" 2>/dev/null || echo '{"error": "timeout"}')
echo "Root response:"
echo "$ROOT_RESPONSE" | jq . 2>/dev/null || echo "$ROOT_RESPONSE"

# Step 6: Test optimization
if echo "$HEALTH_RESPONSE" | jq -e '.status' > /dev/null 2>&1; then
    echo ""
    echo "🍽️  Step 6: Testing meal optimization..."

    OPTIMIZER_RESPONSE=$(curl -s -m 45 -X POST "https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/optimize" \
      -H "Content-Type: application/json" \
      -d '{
        "user": {
          "target_array": [2300, 394, 76, 258]
        },
        "meal_fraction": 0.3,
        "solveur": "hybride",
        "sample_size": 500
      }' 2>/dev/null || echo '{"error": "request_failed"}')

    echo "Optimization response:"
    echo "$OPTIMIZER_RESPONSE" | jq . 2>/dev/null || echo "$OPTIMIZER_RESPONSE"

    if echo "$OPTIMIZER_RESPONSE" | jq -e '.products_used' > /dev/null 2>&1; then
        PRODUCTS_USED=$(echo "$OPTIMIZER_RESPONSE" | jq -r '.products_used')
        SOLVER=$(echo "$OPTIMIZER_RESPONSE" | jq -r '.solver')
        echo ""
        echo "✅ Meal optimization working!"
        echo "   🔧 Solver: $SOLVER"
        echo "   📦 Products used: $PRODUCTS_USED"
    else
        echo ""
        echo "❌ Meal optimization still not working"
    fi
else
    echo ""
    echo "❌ Health check still failing, skipping optimization test"
fi

# Step 7: Check logs
echo ""
echo "📝 Step 7: Checking container logs..."

echo "Recent container logs (last 5 minutes):"
aws logs tail "/ecs/nutria-meal-optimizer" \
    --since 5m \
    --region eu-west-1 \
    --max-items 15 2>/dev/null || echo "No recent logs found"

# Step 8: Check task status
echo ""
echo "📋 Step 8: Checking task status..."

TASK_ARN=$(aws ecs list-tasks \
    --cluster "nutria-cluster-adcd61bb0cdcd880" \
    --service-name "nutria-meal-optimizer-service" \
    --region eu-west-1 \
    --query 'taskArns[0]' \
    --output text)

if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    echo "Current task: ${TASK_ARN##*/}"

    TASK_STATUS=$(aws ecs describe-tasks \
        --cluster "nutria-cluster-adcd61bb0cdcd880" \
        --tasks "$TASK_ARN" \
        --region eu-west-1 \
        --query 'tasks[0].{LastStatus:lastStatus,HealthStatus:healthStatus,CreatedAt:createdAt}')

    echo "Task status: $TASK_STATUS"
else
    echo "❌ No active tasks found"
fi

# Step 9: Final summary
echo ""
echo "🎯 Final Status Summary:"
echo "========================"

if echo "$HEALTH_RESPONSE" | jq -e '.status' > /dev/null 2>&1; then
    echo "✅ Health Check: Working"
else
    echo "❌ Health Check: Failed"
fi

if echo "$ROOT_RESPONSE" | jq -e '.service' > /dev/null 2>&1; then
    echo "✅ Container: Responding"
else
    echo "❌ Container: Not responding"
fi

if echo "$OPTIMIZER_RESPONSE" | jq -e '.products_used' > /dev/null 2>&1; then
    echo "✅ Optimization: Working"
else
    echo "❌ Optimization: Failed"
fi

echo ""
if echo "$HEALTH_RESPONSE" | jq -e '.status' > /dev/null 2>&1 && echo "$OPTIMIZER_RESPONSE" | jq -e '.products_used' > /dev/null 2>&1; then
    echo "🎉 SUCCESS: Complete Nutria system is now operational!"
    echo ""
    echo "🌐 Your working endpoints:"
    echo "   Targets: https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/targets"
    echo "   Optimizer: https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/optimize"
    echo ""
    echo "🧪 Test commands:"
    echo "# Get nutrition targets:"
    echo "curl -X POST 'https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/targets' \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"gender\":\"male\",\"age\":30,\"height\":175,\"weight_in_kg\":70,\"activity_level\":\"moderate\",\"objectif\":\"weight loss\"}'"
    echo ""
    echo "# Optimize meal plan:"
    echo "curl -X POST 'https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/optimize' \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"user\":{\"target_array\":[2300,394,76,258]},\"solveur\":\"hybride\"}'"

elif echo "$HEALTH_RESPONSE" | jq -e '.status' > /dev/null 2>&1; then
    echo "🟡 PARTIAL SUCCESS: Container is healthy but optimization needs troubleshooting"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check logs: aws logs tail '/ecs/nutria-meal-optimizer' --follow --region eu-west-1"
    echo "2. Test direct ALB: curl 'http://nutria-alb-adcd61-970243738.eu-west-1.elb.amazonaws.com/optimize' -X POST -H 'Content-Type: application/json' -d '{\"user\":{\"target_array\":[2300,394,76,258]}}'"

else
    echo "❌ NEEDS MORE TROUBLESHOOTING: Container still not responding"
    echo ""
    echo "Next steps:"
    echo "1. Check logs: aws logs tail '/ecs/nutria-meal-optimizer' --follow --region eu-west-1"
    echo "2. Check task details: aws ecs describe-tasks --cluster nutria-cluster-adcd61bb0cdcd880 --tasks $TASK_ARN --region eu-west-1"
    echo "3. Check security group: Ensure port 8080 is open"
fi

echo ""
echo "🎯 Fix completed!"