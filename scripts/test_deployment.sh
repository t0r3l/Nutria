#!/bin/bash

set -e

# Get API endpoints from Terraform output
cd terraform
API_BASE=$(terraform output -raw api_gateway_url)
cd ..

TARGETS_ENDPOINT="$API_BASE/compute-targets"
OPTIMIZER_ENDPOINT="$API_BASE/meal-optimizer"

echo "🧪 Testing deployed Lambda functions..."

# Test compute-targets endpoint
echo "Testing compute-targets endpoint..."
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
echo "$TARGETS_RESPONSE" | python3 -m json.tool

# Test meal-optimizer endpoint (requires targets output)
echo ""
echo "Testing meal-optimizer endpoint..."

# Extract target_array from targets response for meal optimizer test
TARGET_ARRAY=$(echo "$TARGETS_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'target_array' in data:
    print(json.dumps(data['target_array']))
else:
    print('[2000, 600, 80, 200]')  # fallback values
")

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
echo "$OPTIMIZER_RESPONSE" | python3 -m json.tool

echo ""
echo "✅ Testing completed!"

---