# Test your complete Nutria system endpoints

echo "🎯 Testing Lambda Targets Endpoint..."
TARGETS_RESPONSE=$(curl -s -X POST "https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/targets" \
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
echo "$TARGETS_RESPONSE" | jq . 2>/dev/null || echo "$TARGETS_RESPONSE"

# Extract target array for optimization
TARGET_ARRAY=$(echo "$TARGETS_RESPONSE" | jq -c '.target_array' 2>/dev/null)
echo "Target Array: $TARGET_ARRAY"

echo ""
echo "🍽️ Testing API Gateway Optimizer Endpoint..."
OPTIMIZER_RESPONSE=$(curl -s -m 60 -X POST "https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/optimize" \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"target_array\": $TARGET_ARRAY
    },
    \"meal_fraction\": 0.3,
    \"solveur\": \"hybride\",
    \"sample_size\": 1000
  }")

echo "API Gateway Optimizer Response:"
echo "$OPTIMIZER_RESPONSE" | jq . 2>/dev/null || echo "$OPTIMIZER_RESPONSE"

echo ""
echo "🏥 Testing ALB Direct Access..."
ALB_HEALTH=$(curl -s -m 10 "http://nutria-alb-adcd61-970243738.eu-west-1.elb.amazonaws.com/health" 2>/dev/null)
echo "ALB Health Response:"
echo "$ALB_HEALTH" | jq . 2>/dev/null || echo "$ALB_HEALTH"

echo ""
echo "🔧 Testing ALB Optimizer Direct..."
ALB_OPTIMIZER=$(curl -s -m 60 -X POST "http://nutria-alb-adcd61-970243738.eu-west-1.elb.amazonaws.com/optimize" \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"target_array\": $TARGET_ARRAY
    },
    \"meal_fraction\": 0.3,
    \"solveur\": \"hybride\",
    \"sample_size\": 500
  }" 2>/dev/null)

echo "ALB Direct Optimizer Response:"
echo "$ALB_OPTIMIZER" | jq . 2>/dev/null || echo "$ALB_OPTIMIZER"

echo ""
echo "📊 Summary:"
echo "==========="

# Check Lambda
if echo "$TARGETS_RESPONSE" | jq -e '.calculations.tdee' > /dev/null 2>&1; then
    echo "✅ Lambda Targets: Working"
    TDEE=$(echo "$TARGETS_RESPONSE" | jq -r '.calculations.tdee')
    echo "   TDEE: $TDEE calories"
else
    echo "❌ Lambda Targets: Failed"
fi

# Check API Gateway Optimizer
if echo "$OPTIMIZER_RESPONSE" | jq -e '.products_used' > /dev/null 2>&1; then
    echo "✅ API Gateway Optimizer: Working"
    PRODUCTS=$(echo "$OPTIMIZER_RESPONSE" | jq -r '.products_used')
    echo "   Products in plan: $PRODUCTS"
else
    echo "❌ API Gateway Optimizer: Failed"
fi

# Check ALB Health
if echo "$ALB_HEALTH" | jq -e '.status' > /dev/null 2>&1; then
    echo "✅ ALB Health: Working"
else
    echo "❌ ALB Health: Failed"
fi

# Check ALB Direct
if echo "$ALB_OPTIMIZER" | jq -e '.products_used' > /dev/null 2>&1; then
    echo "✅ ALB Direct: Working"
else
    echo "❌ ALB Direct: Failed"
fi