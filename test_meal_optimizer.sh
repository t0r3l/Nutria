#!/bin/bash

# Test script for Fargate meal optimizer using curl
# Usage: ./test_meal_optimizer.sh [URL]

# Default URL (update with your ALB URL)
URL="${1:-http://localhost:8080}"

echo "=== Testing Fargate Meal Optimizer ==="
echo "URL: $URL"
echo

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Health Check
echo "1. Health Check:"
curl -s -X GET "$URL/health" | jq '.' || echo "Health check failed"
echo

# 2. Basic Optimization Request
echo "2. Basic Optimization Request:"
curl -s -X POST "$URL/optimize" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "target_array": [2000, 600, 80, 200]
    },
    "meal_fraction": 0.3,
    "solveur": "hybride",
    "sample_size": 1000
  }' | jq '.' || echo "Optimization failed"
echo

# 3. Test with different meal fractions
echo "3. Testing different meal fractions:"
for fraction in 0.2 0.3 0.4; do
  echo -n "  Meal fraction $fraction: "
  response=$(curl -s -X POST "$URL/optimize" \
    -H "Content-Type: application/json" \
    -d "{
      \"user\": {
        \"target_array\": [2000, 600, 80, 200]
      },
      \"meal_fraction\": $fraction,
      \"solveur\": \"hybride\",
      \"sample_size\": 500
    }")
  
  if echo "$response" | jq -e '.meal_plan' > /dev/null 2>&1; then
    products=$(echo "$response" | jq '.products_used')
    echo -e "${GREEN}✓${NC} Success - $products products"
  else
    echo -e "${RED}✗${NC} Failed"
  fi
done
echo

# 4. Test different solvers
echo "4. Testing different solvers:"
for solver in "hybride" "nnls" "lsq_linear"; do
  echo -n "  Solver $solver: "
  response=$(curl -s -X POST "$URL/optimize" \
    -H "Content-Type: application/json" \
    -d "{
      \"user\": {
        \"target_array\": [2000, 600, 80, 200]
      },
      \"meal_fraction\": 0.3,
      \"solveur\": \"$solver\",
      \"sample_size\": 500
    }")
  
  if echo "$response" | jq -e '.meal_plan' > /dev/null 2>&1; then
    products=$(echo "$response" | jq '.products_used')
    echo -e "${GREEN}✓${NC} Success - $products products"
  else
    echo -e "${RED}✗${NC} Failed"
  fi
done
echo

# 5. Performance test with different sample sizes
echo "5. Performance test (sample sizes):"
for size in 100 500 1000 2000; do
  echo -n "  Sample size $size: "
  start_time=$(date +%s.%N)
  
  response=$(curl -s -X POST "$URL/optimize" \
    -H "Content-Type: application/json" \
    -d "{
      \"user\": {
        \"target_array\": [2000, 600, 80, 200]
      },
      \"meal_fraction\": 0.3,
      \"solveur\": \"hybride\",
      \"sample_size\": $size
    }")
  
  end_time=$(date +%s.%N)
  duration=$(echo "$end_time - $start_time" | bc)
  
  if echo "$response" | jq -e '.meal_plan' > /dev/null 2>&1; then
    products=$(echo "$response" | jq '.products_used')
    echo -e "${GREEN}✓${NC} Success - $products products in ${duration}s"
  else
    echo -e "${RED}✗${NC} Failed"
  fi
done
echo

# 6. Error handling test
echo "6. Error handling tests:"
echo -n "  Missing user data: "
response=$(curl -s -w "\n%{http_code}" -X POST "$URL/optimize" \
  -H "Content-Type: application/json" \
  -d '{}')
status_code=$(echo "$response" | tail -n1)
if [ "$status_code" = "400" ]; then
  echo -e "${GREEN}✓${NC} Correctly returned 400"
else
  echo -e "${RED}✗${NC} Expected 400, got $status_code"
fi

echo -n "  Invalid target array: "
response=$(curl -s -w "\n%{http_code}" -X POST "$URL/optimize" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "target_array": [2000]
    }
  }')
status_code=$(echo "$response" | tail -n1)
if [ "$status_code" = "500" ] || [ "$status_code" = "400" ]; then
  echo -e "${GREEN}✓${NC} Correctly returned error"
else
  echo -e "${RED}✗${NC} Expected error, got $status_code"
fi

echo
echo "=== Test completed ==="