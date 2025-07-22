#!/bin/bash
# emergency_fix.sh - Fix all current issues

set -e

echo "🚨 Emergency fix for Nutria deployment issues"
echo "=============================================="

# Step 1: Fix Lambda test (JSON syntax issue)
echo "🎯 Step 1: Testing Lambda with correct JSON..."

TARGETS_ENDPOINT="https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/targets"

curl -X POST "$TARGETS_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "gender": "male",
    "age": 30,
    "height": 175,
    "weight_in_kg": 70,
    "activity_level": "moderate",
    "objectif": "weight loss"
  }'

echo ""
echo ""

# Step 2: Check if we have the Fargate app files
echo "📁 Step 2: Checking Fargate application files..."

if [ ! -f "fargate/app.py" ]; then
    echo "❌ fargate/app.py not found!"
    echo "Creating fargate directory and files..."

    mkdir -p fargate

    # Create app.py with your hybrid optimization
    cat > fargate/app.py << 'EOF'
from flask import Flask, request, jsonify
import json
import os
import numpy as np
import polars as pl
from scipy.optimize import nnls, lsq_linear
import boto3
from io import StringIO
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

def create_optimal_meals_hybrid(user_targets, products_df, solveur="hybride", meal_fraction=0.3):
    """Hybrid meal optimization method"""
    # Apply meal fraction to targets
    targets = np.array(user_targets) * meal_fraction
    targets = np.append(targets[:4], 25 * meal_fraction)

    logger.info(f"Optimization targets: {targets}")

    # Prepare nutrition matrix
    nutr_cols = ["energy-kcal", "proteins", "fat", "carbohydrates", "fiber"]

    # Handle missing columns
    missing_cols = [col for col in nutr_cols if col not in products_df.columns]
    if missing_cols:
        logger.warning(f"Missing columns: {missing_cols}, using zeros")
        for col in missing_cols:
            products_df = products_df.with_columns(pl.lit(0.0).alias(col))

    # Add portion_maximale if missing
    if "portion_maximale" not in products_df.columns:
        products_df = products_df.with_columns(pl.lit(200.0).alias("portion_maximale"))

    arr = products_df.select(nutr_cols).to_numpy() / 100.0
    M = arr.T

    # Bounds
    lwr_bound = np.zeros(M.shape[1])
    higher_bound = products_df["portion_maximale"].to_numpy()

    if solveur == "hybride":
        # Step 1: NNLS selection
        x_init, _ = nnls(M, targets)
        masque_x = x_init > 0

        indices_conserves = np.where(masque_x)[0]
        logger.info(f"Selected {len(indices_conserves)} products")

        if len(indices_conserves) == 0:
            # Fallback
            nutrition_scores = np.sum(arr, axis=1)
            top_indices = np.argsort(nutrition_scores)[-50:]
            indices_conserves = top_indices
            masque_x = np.zeros(len(products_df), dtype=bool)
            masque_x[indices_conserves] = True

        # Step 2: Filter and optimize
        M_filtre = M[:, masque_x]
        products_filtre = products_df.filter(
            pl.Series(range(len(products_df))).is_in(indices_conserves.tolist())
        )

        lwr_bound_filtre = np.zeros(M_filtre.shape[1])
        uppr_bound_filtre = products_filtre["portion_maximale"].to_numpy()

        result = lsq_linear(M_filtre, targets, bounds=(lwr_bound_filtre, uppr_bound_filtre), method="bvls")
        x = result.x
        obtained = M_filtre @ x

        plan_data = {
            "product_name": products_filtre["product_name"].to_list(),
            "quantité_g": x.tolist()
        }
    else:
        # Simple NNLS
        x, _ = nnls(M, targets)
        obtained = M @ x
        plan_data = {
            "product_name": products_df["product_name"].to_list(),
            "quantité_g": x.tolist()
        }

    # Filter and sort
    plan_df = pl.DataFrame(plan_data).filter(pl.col("quantité_g") > 1e-6).sort("quantité_g", descending=True)
    meal_plan = plan_df.to_dicts()

    verification = {
        "obtained": obtained.tolist(),
        "targets": targets.tolist()
    }

    return meal_plan, verification

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'service': 'nutria-meal-optimizer'}), 200

@app.route('/optimize', methods=['POST'])
def optimize_meal():
    try:
        bucket_name = os.environ.get('S3_BUCKET_NAME')
        file_key = os.environ.get('CSV_FILE_KEY')

        data = request.get_json()
        user_data = data.get('user')
        meal_fraction = data.get('meal_fraction', 0.3)
        solveur = data.get('solveur', 'hybride')
        sample_size = data.get('sample_size', 1000)

        if not user_data or 'target_array' not in user_data:
            return jsonify({'error': 'Missing user data with target_array'}), 400

        # Load from S3
        s3_client = boto3.client('s3')
        response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
        csv_content = response['Body'].read().decode('utf-8')

        products_df = pl.read_csv(StringIO(csv_content), ignore_errors=True)

        if len(products_df) > sample_size:
            products_df = products_df.sample(sample_size)

        meal_plan, verification = create_optimal_meals_hybrid(
            user_data['target_array'], products_df, solveur, meal_fraction
        )

        return jsonify({
            "meal_plan": meal_plan,
            "verification": verification,
            "solver": solveur,
            "products_used": len(meal_plan),
            "deployment_info": {"type": "fargate", "optimization_method": "hybrid"}
        }), 200

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/', methods=['GET'])
def root():
    return jsonify({'service': 'Nutria Meal Optimizer', 'version': '2.0.0'}), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
EOF

    # Create Dockerfile
    cat > fargate/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc g++ gfortran libblas-dev liblapack-dev curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8080
ENV PORT=8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["python", "app.py"]
EOF

    # Create requirements.txt
    cat > fargate/requirements.txt << 'EOF'
flask==2.3.3
numpy==1.24.3
polars==0.20.2
scipy==1.10.1
boto3==1.34.34
gunicorn==21.2.0
werkzeug==2.3.7
EOF

    echo "✅ Created Fargate application files"
else
    echo "✅ Fargate files exist"
fi

# Step 3: Build and push container image
echo ""
echo "🐳 Step 3: Building and pushing container image..."

# Get ECR URL
ECR_URL=$(terraform output -raw ecr_repository_url)
echo "ECR Repository: $ECR_URL"

cd fargate

echo "Building Docker image..."
docker build -t nutria-meal-optimizer . --no-cache

echo "Logging into ECR..."
aws ecr get-login-password --region eu-west-1 | \
    docker login --username AWS --password-stdin $ECR_URL

echo "Pushing image to ECR..."
docker tag nutria-meal-optimizer:latest $ECR_URL:latest
docker push $ECR_URL:latest

cd ..

echo "✅ Container image built and pushed"

# Step 4: Force restart ECS service
echo ""
echo "🔄 Step 4: Restarting ECS service..."

CLUSTER_NAME="nutria-cluster-adcd61bb0cdcd880"
SERVICE_NAME="nutria-meal-optimizer-service"

echo "Forcing new deployment..."
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --force-new-deployment \
    --desired-count 1 \
    --region eu-west-1 \
    --no-cli-pager

echo "✅ Service restart initiated"

# Step 5: Wait and monitor
echo ""
echo "⏳ Step 5: Waiting for service to start (3 minutes)..."

echo "Waiting 60 seconds for initial startup..."
sleep 60

# Check task status
echo "Checking task status..."
TASK_STATUS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --region eu-west-1 --query 'taskArns[0]' --output text)

if [ "$TASK_STATUS" != "None" ] && [ "$TASK_STATUS" != "" ]; then
    echo "Task ARN: $TASK_STATUS"

    # Get task details
    aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_STATUS" --region eu-west-1 --query 'tasks[0].{LastStatus:lastStatus,HealthStatus:healthStatus,StoppedReason:stoppedReason}' --output table
else
    echo "No tasks found. Checking service events..."
    aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region eu-west-1 --query 'services[0].events[:3]' --output table
fi

echo ""
echo "Waiting additional 2 minutes for full startup..."
sleep 120

# Step 6: Test everything
echo ""
echo "🧪 Step 6: Testing endpoints..."

# Test Lambda again
echo "Testing Lambda..."
LAMBDA_RESPONSE=$(curl -s -X POST "$TARGETS_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "gender": "male",
    "age": 30,
    "height": 175,
    "weight_in_kg": 70,
    "activity_level": "moderate",
    "objectif": "weight loss"
  }')

echo "Lambda Response:"
echo "$LAMBDA_RESPONSE" | jq . 2>/dev/null || echo "$LAMBDA_RESPONSE"

# Test ALB health
ALB_URL="http://nutria-alb-adcd61-970243738.eu-west-1.elb.amazonaws.com"
echo ""
echo "Testing ALB health..."
HEALTH_RESPONSE=$(curl -s -m 10 "$ALB_URL/health" 2>/dev/null || echo '{"error": "timeout"}')
echo "Health Response: $HEALTH_RESPONSE"

# Test optimizer
echo ""
echo "Testing optimizer..."
OPTIMIZER_ENDPOINT="https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/optimize"

OPTIMIZER_RESPONSE=$(curl -s -m 30 -X POST "$OPTIMIZER_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "target_array": [2000, 600, 80, 200]
    },
    "meal_fraction": 0.3,
    "solveur": "hybride",
    "sample_size": 500
  }' 2>/dev/null || echo '{"error": "request_failed"}')

echo "Optimizer Response:"
echo "$OPTIMIZER_RESPONSE" | jq . 2>/dev/null || echo "$OPTIMIZER_RESPONSE"

echo ""
echo "🎯 Emergency fix completed!"
echo ""
echo "If issues persist, check:"
echo "1. Container logs: aws logs tail '/ecs/nutria-meal-optimizer' --follow --region eu-west-1"
echo "2. Task status: aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region eu-west-1"