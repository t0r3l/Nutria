#!/bin/bash
# diagnose_fargate.sh - Diagnose and fix Fargate container issues

set -e

echo "🔍 Diagnosing Fargate container issues..."

CLUSTER_NAME="nutria-cluster-adcd61bb0cdcd880"
SERVICE_NAME="nutria-meal-optimizer-service"
AWS_REGION="eu-west-1"

# Step 1: Check task status
echo "📋 Step 1: Checking ECS task details..."

TASK_ARN=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --region $AWS_REGION \
    --query 'taskArns[0]' \
    --output text)

if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    echo "✅ Found task: ${TASK_ARN##*/}"

    # Get task details
    TASK_DETAILS=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks "$TASK_ARN" \
        --region $AWS_REGION \
        --query 'tasks[0]')

    TASK_STATUS=$(echo "$TASK_DETAILS" | jq -r '.lastStatus')
    HEALTH_STATUS=$(echo "$TASK_DETAILS" | jq -r '.healthStatus // "UNKNOWN"')
    STOPPED_REASON=$(echo "$TASK_DETAILS" | jq -r '.stoppedReason // "N/A"')

    echo "   📊 Task Status: $TASK_STATUS"
    echo "   🏥 Health Status: $HEALTH_STATUS"
    echo "   🛑 Stopped Reason: $STOPPED_REASON"

    # Check container status
    echo ""
    echo "🐳 Container details:"
    echo "$TASK_DETAILS" | jq -r '.containers[0] | {name: .name, lastStatus: .lastStatus, exitCode: .exitCode, reason: .reason}'

else
    echo "❌ No tasks found"
    echo "Checking service events..."

    aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region $AWS_REGION \
        --query 'services[0].events[:5]' \
        --output table
fi

# Step 2: Check container logs
echo ""
echo "📝 Step 2: Checking container logs..."

echo "Recent container logs:"
aws logs tail "/ecs/nutria-meal-optimizer" \
    --since 30m \
    --region $AWS_REGION \
    --max-items 20 2>/dev/null || echo "No logs found or log group doesn't exist"

# Step 3: Check if ECR image exists
echo ""
echo "🐳 Step 3: Checking ECR image..."

ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")

if [ -n "$ECR_URL" ]; then
    echo "ECR Repository: $ECR_URL"

    # Check if image exists
    IMAGES=$(aws ecr describe-images \
        --repository-name "nutria/meal-optimizer" \
        --region $AWS_REGION \
        --query 'imageDetails[].imageTags[]' \
        --output text 2>/dev/null || echo "")

    if [ -n "$IMAGES" ]; then
        echo "✅ Container images found: $IMAGES"
    else
        echo "❌ No container images found"
        echo "   This is likely the main issue!"
    fi
else
    echo "❌ Could not get ECR URL"
fi

# Step 4: Check task definition
echo ""
echo "📋 Step 4: Checking task definition..."

TASK_DEF_ARN=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region $AWS_REGION \
    --query 'services[0].taskDefinition' \
    --output text)

echo "Task Definition: $TASK_DEF_ARN"

TASK_DEF_DETAILS=$(aws ecs describe-task-definition \
    --task-definition "$TASK_DEF_ARN" \
    --region $AWS_REGION \
    --query 'taskDefinition.containerDefinitions[0]')

echo "Container image in task definition:"
echo "$TASK_DEF_DETAILS" | jq -r '.image'

echo "Container port mappings:"
echo "$TASK_DEF_DETAILS" | jq -r '.portMappings'

echo "Container environment variables:"
echo "$TASK_DEF_DETAILS" | jq -r '.environment'

# Step 5: Check security group
echo ""
echo "🔒 Step 5: Checking security group..."

# Get task network interface
if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    NETWORK_INTERFACES=$(echo "$TASK_DETAILS" | jq -r '.attachments[0].details[] | select(.name=="networkInterfaceId") | .value' 2>/dev/null || echo "")

    if [ -n "$NETWORK_INTERFACES" ]; then
        echo "Network Interface: $NETWORK_INTERFACES"

        # Get security groups
        SECURITY_GROUPS=$(aws ec2 describe-network-interfaces \
            --network-interface-ids "$NETWORK_INTERFACES" \
            --region $AWS_REGION \
            --query 'NetworkInterfaces[0].Groups[].GroupId' \
            --output text 2>/dev/null || echo "")

        echo "Security Groups: $SECURITY_GROUPS"

        # Check security group rules
        for sg in $SECURITY_GROUPS; do
            echo "Security group $sg rules:"
            aws ec2 describe-security-groups \
                --group-ids "$sg" \
                --region $AWS_REGION \
                --query 'SecurityGroups[0].IpPermissions' \
                --output table 2>/dev/null || echo "Could not get rules"
        done
    fi
fi

# Step 6: Suggested fixes
echo ""
echo "🛠️  Step 6: Suggested fixes based on diagnosis..."

if [ -z "$IMAGES" ]; then
    echo ""
    echo "🚨 MAIN ISSUE: No container image found in ECR"
    echo "   This is why the container can't start!"
    echo ""
    echo "   Fix: Build and push the container image"
    echo "   1. cd fargate"
    echo "   2. docker build -t nutria-meal-optimizer ."
    echo "   3. aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL"
    echo "   4. docker tag nutria-meal-optimizer:latest $ECR_URL:latest"
    echo "   5. docker push $ECR_URL:latest"
    echo "   6. aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment --region $AWS_REGION"
fi

if [ "$HEALTH_STATUS" = "UNHEALTHY" ]; then
    echo ""
    echo "🏥 HEALTH CHECK ISSUE"
    echo "   The container is starting but health checks are failing"
    echo "   Possible causes:"
    echo "   - App not listening on port 8080"
    echo "   - /health endpoint not responding"
    echo "   - Security group blocking port 8080"
fi

if [ "$TASK_STATUS" = "STOPPED" ]; then
    echo ""
    echo "🛑 CONTAINER STOPPING"
    echo "   Check container logs for startup errors"
    echo "   Common issues:"
    echo "   - Missing environment variables"
    echo "   - Python import errors"
    echo "   - Port binding issues"
fi

# Step 7: Quick fix script
echo ""
echo "🚀 Quick fix commands:"

cat << 'EOF'

# If no image in ECR, build and push:
cd fargate
docker build -t nutria-meal-optimizer . --no-cache
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $ECR_URL
docker tag nutria-meal-optimizer:latest $ECR_URL:latest
docker push $ECR_URL:latest
cd ..

# Force restart service with new image:
aws ecs update-service \
  --cluster nutria-cluster-adcd61bb0cdcd880 \
  --service nutria-meal-optimizer-service \
  --force-new-deployment \
  --region eu-west-1

# Wait and check logs:
sleep 180
aws logs tail '/ecs/nutria-meal-optimizer' --follow --region eu-west-1

EOF

echo ""
echo "🎯 Diagnosis completed!"
echo ""
echo "Most likely issue: Missing container image in ECR"
echo "Run the quick fix commands above to resolve this."