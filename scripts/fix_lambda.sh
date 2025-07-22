#!/bin/bash
# final_lambda_fix.sh - Fix API Gateway integration and calculation bug

set -e

echo "🔧 Final Lambda fix - API Gateway + Calculation bug..."

LAMBDA_NAME="nutria-compute-targets-adcd61bb0cdcd880"

# Step 1: Create corrected Lambda function
echo "📝 Creating corrected Lambda function..."

cat > lambda_functions/targets/lambda_function.py << 'EOF'
import json
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

ACTIVITY_MULTIPLIERS = {
    "very low": 1.2,
    "low": 1.375,
    "moderate": 1.55,
    "high": 1.725,
    "very high": 1.9
}

OBJECTIF_CALORIES = {
    "maintain": 0,
    "weight loss": -250,
    "weight gain": 250
}

def computeTargets(event, context):
    """
    Lambda function that calculates nutrition targets
    Handles both direct invocation and API Gateway events
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")

        # Parse event body - handle API Gateway format
        if 'body' in event:
            if event['body'] is None:
                body = event
            elif isinstance(event['body'], str):
                try:
                    body = json.loads(event['body'])
                except json.JSONDecodeError:
                    logger.error(f"Failed to parse body: {event['body']}")
                    return {
                        'statusCode': 400,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Invalid JSON in request body'})
                    }
            else:
                body = event['body']
        else:
            # Direct invocation
            body = event

        logger.info(f"Parsed body: {json.dumps(body)}")

        # Extract parameters
        gender = body.get('gender')
        age = body.get('age')
        height = body.get('height')
        weight_in_kg = body.get('weight_in_kg')
        activity_level = body.get('activity_level')
        objectif = body.get('objectif')
        body_fat_percent = body.get('body_fat_percent', 0.12)

        # Validate required parameters
        required_params = ['gender', 'age', 'height', 'weight_in_kg', 'activity_level', 'objectif']
        missing_params = [param for param in required_params if body.get(param) is None]

        if missing_params:
            error_msg = f'Missing required parameters: {", ".join(missing_params)}'
            logger.error(error_msg)
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': error_msg})
            }

        # Validate activity level
        if activity_level not in ACTIVITY_MULTIPLIERS:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Invalid activity_level. Must be one of: {list(ACTIVITY_MULTIPLIERS.keys())}'})
            }

        # Validate objectif
        if objectif not in OBJECTIF_CALORIES:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Invalid objectif. Must be one of: {list(OBJECTIF_CALORIES.keys())}'})
            }

        # Calculate weight conversions
        weight_in_pounds = weight_in_kg * 2.20462262185

        # Calculate lean body mass
        lean_body_mass_in_kg = weight_in_kg - (weight_in_kg * body_fat_percent)
        lean_body_mass_in_pounds = lean_body_mass_in_kg * 2.20462262185

        # Get multipliers
        activity_multiplier = ACTIVITY_MULTIPLIERS[activity_level]
        objectif_calories = OBJECTIF_CALORIES[objectif]

        # Calculate BMR using Mifflin-St Jeor equation
        if gender == "male":
            bmr = 10 * weight_in_kg + 6.25 * height - 5 * age + 5
        elif gender == "female":
            bmr = 10 * weight_in_kg + 6.25 * height - 5 * age - 161
        else:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Gender must be "male" or "female"'})
            }

        # Calculate TDEE - FIXED calculation
        # Base TDEE
        base_tdee = bmr * activity_multiplier
        # Apply objective adjustment (percentage of base TDEE, not absolute calories)
        tdee = base_tdee * (1 + objectif_calories / 2500)  # More reasonable adjustment

        # Calculate macro targets
        protein_g = lean_body_mass_in_kg * 1.6
        protein_cal = protein_g * 4

        lipid_cal = 0.30 * tdee
        lipid_g = lipid_cal / 9

        glucides_cal = 0.45 * tdee
        glucides_g = glucides_cal / 4

        # Create target array
        target_array = [
            tdee,
            protein_cal,
            lipid_g,
            glucides_g
        ]

        # Prepare complete response
        response_data = {
            'user_info': {
                'gender': gender,
                'age': age,
                'height': height,
                'weight_in_kg': weight_in_kg,
                'weight_in_pounds': weight_in_pounds,
                'activity_level': activity_level,
                'objectif': objectif,
                'body_fat_percent': body_fat_percent
            },
            'calculations': {
                'bmr': bmr,
                'base_tdee': base_tdee,
                'tdee': tdee,
                'lean_body_mass_kg': lean_body_mass_in_kg,
                'lean_body_mass_pounds': lean_body_mass_in_pounds,
                'activity_multiplier': activity_multiplier,
                'objectif_calories': objectif_calories
            },
            'targets': {
                'protein_g': protein_g,
                'protein_cal': protein_cal,
                'lipid_g': lipid_g,
                'lipid_cal': lipid_cal,
                'glucides_g': glucides_g,
                'glucides_cal': glucides_cal
            },
            'target_array': target_array
        }

        logger.info(f"Calculated TDEE: {tdee}, BMR: {bmr}")

        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(response_data)
        }

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }
EOF

echo "✅ Created corrected Lambda function"

# Step 2: Update Lambda function
echo ""
echo "🔄 Updating Lambda function..."

cd lambda_functions/targets
zip -r ../../lambda_update.zip . -q
cd ../..

aws lambda update-function-code \
    --function-name "$LAMBDA_NAME" \
    --zip-file fileb://lambda_update.zip \
    --region eu-west-1 > /dev/null

echo "Waiting for function update..."
aws lambda wait function-updated --function-name "$LAMBDA_NAME" --region eu-west-1

echo "✅ Function updated"

# Step 3: Test corrected function
echo ""
echo "🧪 Testing corrected function..."

# Test direct invocation
echo "Direct invocation test:"
echo '{"gender":"male","age":30,"height":175,"weight_in_kg":70,"activity_level":"moderate","objectif":"weight loss"}' > test.json

aws lambda invoke \
    --function-name "$LAMBDA_NAME" \
    --payload file://test.json \
    --region eu-west-1 \
    --cli-binary-format raw-in-base64-out \
    response.json

echo "Direct response:"
DIRECT_RESPONSE=$(cat response.json)
echo "$DIRECT_RESPONSE" | jq . 2>/dev/null || echo "$DIRECT_RESPONSE"

# Extract key values for verification
TDEE=$(echo "$DIRECT_RESPONSE" | jq -r '.body' | jq -r '.calculations.tdee' 2>/dev/null || echo "unknown")
BMR=$(echo "$DIRECT_RESPONSE" | jq -r '.body' | jq -r '.calculations.bmr' 2>/dev/null || echo "unknown")

echo ""
echo "📊 Key values:"
echo "   BMR: $BMR calories"
echo "   TDEE: $TDEE calories"

# Step 4: Test API Gateway
echo ""
echo "🌐 Testing API Gateway..."

API_RESPONSE=$(curl -s -X POST "https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/targets" \
  -H "Content-Type: application/json" \
  -d @test.json)

echo "API Gateway response:"
echo "$API_RESPONSE" | jq . 2>/dev/null || echo "$API_RESPONSE"

# Step 5: Verify results
echo ""
echo "🎯 Verification:"

if echo "$DIRECT_RESPONSE" | jq -e '.body' | jq -e '.calculations.tdee' > /dev/null 2>&1; then
    DIRECT_TDEE=$(echo "$DIRECT_RESPONSE" | jq -r '.body' | jq -r '.calculations.tdee')
    if (( $(echo "$DIRECT_TDEE > 0" | bc -l) )); then
        echo "✅ Direct invocation: Working (TDEE: $DIRECT_TDEE)"
    else
        echo "❌ Direct invocation: TDEE calculation still wrong"
    fi
else
    echo "❌ Direct invocation: Failed"
fi

if echo "$API_RESPONSE" | jq -e '.calculations.tdee' > /dev/null 2>&1; then
    API_TDEE=$(echo "$API_RESPONSE" | jq -r '.calculations.tdee')
    echo "✅ API Gateway: Working (TDEE: $API_TDEE)"
elif echo "$API_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo "❌ API Gateway: Still has error"
    echo "   Error: $(echo "$API_RESPONSE" | jq -r '.error')"
else
    echo "❌ API Gateway: Unexpected response format"
fi

# Step 6: Test with target array extraction
echo ""
echo "🎯 Testing target array extraction..."

if echo "$API_RESPONSE" | jq -e '.target_array' > /dev/null 2>&1; then
    TARGET_ARRAY=$(echo "$API_RESPONSE" | jq -c '.target_array')
    echo "✅ Target array extracted: $TARGET_ARRAY"
    echo ""
    echo "🍽️  Ready for meal optimization!"
    echo "You can now use this target array with the Fargate optimizer:"
    echo "curl -X POST 'https://7968q3waxk.execute-api.eu-west-1.amazonaws.com/dev/optimize' \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"user\":{\"target_array\":$TARGET_ARRAY},\"solveur\":\"hybride\"}'"
else
    echo "❌ Could not extract target array"
fi

# Cleanup
rm -f test.json response.json lambda_update.zip

echo ""
echo "🎉 Lambda fix completed!"