
set -e

echo "🔧 Rebuilding meal optimizer container with fixes..."

# Clean up any existing images
docker image rm meal-optimizer:latest 2>/dev/null || true
docker system prune -f

# Get ECR details
ECR_URL=$(terraform output -raw ecr_repository_url)
AWS_REGION="eu-west-1"

echo "🐳 Building fixed container..."

# Navigate to meal optimizer directory
cd lambda_functions/meal_optimizer

# Verify files exist
if [ ! -f "Dockerfile" ] || [ ! -f "lambda_function.py" ] || [ ! -f "requirements.txt" ]; then
    echo "❌ Missing required files in lambda_functions/meal_optimizer/"
    echo "Required files:"
    echo "  - Dockerfile"
    echo "  - lambda_function.py"
    echo "  - requirements.txt"
    exit 1
fi

# Build with explicit platform for Lambda
echo "🔨 Building image with Lambda-compatible settings..."
docker build --platform linux/amd64 -t meal-optimizer . --no-cache

# Test the image locally (optional)
echo "🧪 Testing image format..."
docker run --rm meal-optimizer echo "Image format test successful"

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_URL

# Delete old image from ECR
echo "🧹 Cleaning old images from ECR..."
aws ecr batch-delete-image \
    --repository-name nutria/meal-optimizer \
    --image-ids imageTag=latest \
    --region $AWS_REGION 2>/dev/null || echo "No old images to delete"

# Tag and push new image
echo "📤 Pushing new image..."
docker tag meal-optimizer:latest $ECR_URL:latest
docker push $ECR_URL:latest

# Return to root
cd ../..

echo "✅ Container rebuilt and pushed successfully!"
echo "Now run: terraform apply"