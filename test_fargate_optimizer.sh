#!/bin/bash

# Fargate Meal Optimizer Test Script
# This script tests the meal optimizer endpoint deployed on AWS Fargate

# Configuration
ALB_URL="http://nutria-alb-adcd61-970243738.eu-west-1.elb.amazonaws.com"
REGION="eu-west-1"

echo "=== Fargate Meal Optimizer Test ==="
echo "ALB URL: $ALB_URL"
echo "Region: $REGION"
echo

# Test 1: Health Check
echo "1. Testing Health Check..."
echo "   GET $ALB_URL/health"
curl -s -X GET "$ALB_URL/health" --max-time 10 | jq '.' 2>/dev/null || echo "   ❌ Health check failed or timed out"
echo

# Test 2: Basic Optimization Request
echo "2. Testing Meal Optimization..."
echo "   POST $ALB_URL/optimize"
echo "   Request payload:"
cat << 'EOF' | jq '.'
{
  "user": {
    "target_array": [2000, 600, 80, 200]
  },
  "meal_fraction": 0.3,
  "solveur": "hybride",
  "sample_size": 1000
}
EOF

echo
echo "   Sending request (timeout: 30s)..."
response=$(curl -s -X POST "$ALB_URL/optimize" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "target_array": [2000, 600, 80, 200]
    },
    "meal_fraction": 0.3,
    "solveur": "hybride",
    "sample_size": 1000
  }' \
  --max-time 30)

if [ $? -eq 0 ]; then
  echo "$response" | jq '.' 2>/dev/null || echo "   ❌ Invalid JSON response: $response"
else
  echo "   ❌ Request failed or timed out"
fi

echo
echo "3. Checking Fargate Service Status..."
# Check if service is running
service_status=$(aws ecs describe-services \
  --cluster nutria-cluster \
  --services nutria-meal-optimizer \
  --region $REGION \
  2>/dev/null | jq -r '.services[0].status // "NOT_FOUND"')

echo "   Service status: $service_status"

# Check running tasks
running_tasks=$(aws ecs describe-services \
  --cluster nutria-cluster \
  --services nutria-meal-optimizer \
  --region $REGION \
  2>/dev/null | jq -r '.services[0].runningCount // 0')

echo "   Running tasks: $running_tasks"

# Check task definition
task_def=$(aws ecs describe-services \
  --cluster nutria-cluster \
  --services nutria-meal-optimizer \
  --region $REGION \
  2>/dev/null | jq -r '.services[0].taskDefinition // "NOT_FOUND"' | rev | cut -d'/' -f1 | rev)

echo "   Task definition: $task_def"

echo
echo "=== Test Complete ==="
echo
echo "If the service is not responding:"
echo "1. Check CloudWatch logs: aws logs tail /ecs/nutria-meal-optimizer --region $REGION --follow"
echo "2. Check service events: aws ecs describe-services --cluster nutria-cluster --services nutria-meal-optimizer --region $REGION | jq '.services[0].events[:5]'"
echo "3. Restart service: aws ecs update-service --cluster nutria-cluster --service nutria-meal-optimizer --force-new-deployment --region $REGION"