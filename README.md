# Nutria - Nutrition Services Deployment

This repository contains AWS deployment scripts for two nutrition-related microservices:

1. **Lambda Service**: Calculates daily macronutrient targets based on user profile
2. **Fargate API**: Optimizes meal plans using linear programming algorithms

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Lambda        │    │   Fargate       │    │   S3 Bucket     │
│                 │    │                 │    │                 │
│ Target Calc     │    │ Meal Optimizer  │    │ Nutrition Data  │
│ (Lightweight)   │    │ (Heavy Compute) │    │ (CSV Files)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## What This Repo Contains

- **`lambda_functions/targets/`**: Lambda function for nutrition target calculations
- **`fargate/app3.py`**: Fargate service for meal optimization with diet filtering
- **`deploy-universal.sh`**: Universal deployment script for Fargate services
- **`README_DEPLOYMENT.md`**: Detailed deployment documentation (French)

## Quick Start (From Scratch)

### Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Docker** installed and running
3. **AWS Account** with ECS, Lambda, S3, and IAM access

### Step 1: Create AWS Infrastructure

Create the required AWS resources manually (one-time setup):

```bash
# 1. Create ECS cluster
aws ecs create-cluster --cluster-name nutria-dev-cluster --region eu-west-1

# 2. Create VPC (optional if using default VPC)
# Follow VPC creation steps in README_DEPLOYMENT.md if needed

# 3. Create IAM roles for ECS
# - nutria-dev-ecs-execution-role (for container management)
# - nutria-dev-ecs-task-role (for S3 access)

# 4. Create S3 bucket for nutrition data
aws s3 mb s3://nutria-nutrition-data-$(date +%s) --region eu-west-1
# Upload your nutrition CSV file to the bucket
```

### Step 2: Deploy Lambda Function

```bash
# Package and deploy the Lambda function manually via AWS Console
# or use AWS CLI to create the function from lambda_functions/targets/
```

### Step 3: Deploy Fargate Service

Use the universal deployment script to deploy the meal optimizer:

```bash
# Make script executable
chmod +x deploy-universal.sh

# Deploy app3 with optimized Dockerfile
./deploy-universal.sh Dockerfile.fast-app3 app3-optimizer
```

## Deploy Script Overview

The `deploy-universal.sh` script automates the Fargate deployment process:

### What it does:
1. **Generates unique names** with random suffixes for services/repositories
2. **Creates ECR repository** for Docker images
3. **Builds Docker image** using specified Dockerfile
4. **Pushes image to ECR** with authentication
5. **Creates ECS task definition** with proper IAM roles and environment variables
6. **Deploys ECS service** to existing cluster
7. **Returns public IP** for testing

### Usage:
```bash
./deploy-universal.sh <dockerfile-name> [service-prefix]

# Examples:
./deploy-universal.sh Dockerfile.fast-app3 app3-optimizer
./deploy-universal.sh Dockerfile.micro test-app
```

### Script Parameters:
- **Dockerfile**: Path to Dockerfile in fargate/ directory
- **Service Prefix**: Base name for service (gets random suffix)

### What it creates:
- ECR Repository: `nutria/<service-prefix>-<random>`
- ECS Service: `<service-prefix>-<random>`
- Task Definition: Configured with S3 access and environment variables

## Configuration

### Environment Variables (automatically set by deploy script):
- `S3_BUCKET_NAME`: Your nutrition data bucket
- `CSV_FILE_KEY`: Path to nutrition CSV file in S3
- `ENVIRONMENT`: Set to "production" for AWS mode
- `PORT`: Service port (8080)

### S3 Bucket Structure:
```
your-bucket-name/
└── data/
    └── products_nutrition.csv
```

## Testing Deployed Services

### Test Fargate Service:
```bash
# Health check
curl http://<public-ip>:8080/health

# Meal optimization with diet filtering
curl -X POST http://<public-ip>:8080/optimize \
  -H "Content-Type: application/json" \
  -d '{
    "user": {"target_array": [2000, 75, 50, 250]},
    "meal_fraction": 0.3,
    "solveur": "hybride",
    "regime": "Vegan"
  }'
```

### Test Lambda Function:
```bash
# Via AWS CLI
aws lambda invoke --function-name your-lambda-name \
  --payload '{"gender":"male","age":30,"height":180,"weight_in_kg":75,"activity_level":"moderate","objectif":"maintain"}' \
  response.json
```

## Diet Filtering Support

The Fargate service supports filtering by dietary preferences:
- `Vegan`: Plant-based only
- `Vegetarian`: No meat
- `Halal`: Halal-certified foods
- `Casher`: Kosher foods
- `Sans Gluten`: Gluten-free
- `Bio`: Organic foods

## Local Development

Both services support local development mode:
- Set `ENVIRONMENT=local` to use local CSV files instead of S3
- Lambda function works independently of S3
- Fargate service reads from local file system when in local mode

## File Structure

```
NutriaIngestionAndSolver/
├── README.md                          # This file
├── README_DEPLOYMENT.md               # Detailed deployment guide (French)
├── deploy-universal.sh                # Universal deployment script
├── lambda_functions/
│   └── targets/
│       ├── lambda_function.py         # Target calculation logic
│       └── requirements.txt
├── fargate/
│   ├── app3.py                        # Meal optimizer service
│   ├── Dockerfile.fast-app3           # Optimized production Dockerfile
│   ├── requirements.txt
│   └── test3.sh                       # Testing script
└── .gitignore
```

## Need Help?

For detailed step-by-step instructions, see `README_DEPLOYMENT.md` (in French) which contains comprehensive deployment procedures and troubleshooting information.