#!/bin/bash
# build_hybrid_layers.sh
# Only build layer for targets Lambda - meal optimizer uses container

set -e

echo "🔧 Building hybrid deployment layers..."
echo "   📦 Layer for targets Lambda (lightweight)"
echo "   🐳 Container for meal optimizer (no size limits)"

# Create directories
mkdir -p layers builds
mkdir -p lambda_functions/targets
mkdir -p lambda_functions/meal_optimizer

# Build ONLY empty layer for targets Lambda (no scientific dependencies needed)
echo "📦 Building minimal layer for targets Lambda..."
mkdir -p temp_targets/python

# Create a simple utility layer for targets
cat > temp_targets/python/__init__.py << 'EOF'
"""
Minimal layer for nutrition targets Lambda function.
Provides basic utilities for BMR/TDEE calculations.
"""

def layer_info():
    return {
        "name": "nutrition-targets-utilities",
        "purpose": "Basic nutrition calculation utilities",
        "dependencies": "none"
    }
EOF

# Add a simple nutrition utilities module
cat > temp_targets/python/nutrition_utils.py << 'EOF'
"""
Basic nutrition calculation utilities
"""

def validate_gender(gender):
    """Validate gender input"""
    return gender.lower() in ['male', 'female']

def validate_activity_level(activity_level):
    """Validate activity level input"""
    valid_levels = ["very low", "low", "moderate", "high", "very high"]
    return activity_level.lower() in valid_levels

def validate_objective(objective):
    """Validate objective input"""
    valid_objectives = ["maintain", "weight loss", "weight gain"]
    return objective.lower() in valid_objectives

def calculate_bmi(weight_kg, height_cm):
    """Calculate BMI"""
    height_m = height_cm / 100
    return weight_kg / (height_m * height_m)

def get_bmi_category(bmi):
    """Get BMI category"""
    if bmi < 18.5:
        return "underweight"
    elif bmi < 25:
        return "normal"
    elif bmi < 30:
        return "overweight"
    else:
        return "obese"
EOF

cd temp_targets
zip -r ../layers/targets_layer.zip python/
cd ..
rm -rf temp_targets

echo "✅ Targets layer created: layers/targets_layer.zip"

# Show what we built
size=$(stat -f%z "layers/targets_layer.zip" 2>/dev/null || stat -c%s "layers/targets_layer.zip" 2>/dev/null)
size_kb=$((size / 1024))
echo "   Size: ${size_kb}KB (well under 50MB limit)"

# Create requirements files
echo "📝 Creating requirements files..."

# Targets - no external dependencies
cat > lambda_functions/targets/requirements.txt << 'EOF'
# No external dependencies needed
# All calculations use built-in Python libraries
EOF

# Meal optimizer - full dependencies for container
cat > lambda_functions/meal_optimizer/requirements.txt << 'EOF'
numpy==1.24.3
polars==0.20.2
scipy==1.10.1
boto3==1.34.34
EOF

echo "✅ Requirements files created"

# Create Dockerfile for meal optimizer
cat > lambda_functions/meal_optimizer/Dockerfile << 'EOF'
FROM public.ecr.aws/lambda/python:3.11

# Copy requirements and install dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install -r requirements.txt --target ${LAMBDA_TASK_ROOT}

# Copy function code
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD ["lambda_function.create_optimal_meals"]
EOF

echo "✅ Dockerfile created for meal optimizer"

# Create placeholder Lambda functions if they don't exist
if [ ! -f "lambda_functions/targets/lambda_function.py" ]; then
    cat > lambda_functions/targets/lambda_function.py << 'EOF'
import json
from nutrition_utils import validate_gender, validate_activity_level, validate_objective, calculate_bmi, get_bmi_category

# Constants
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
    Lambda function that calculates nutrition targets using layer utilities
    """
    try:
        # Extract parameters from event
        gender = event.get('gender', '').lower()
        age = event.get('age')
        height = event.get('height')
        weight_in_kg = event.get('weight_in_kg')
        activity_level = event.get('activity_level', '').lower()
        objectif = event.get('objectif', '').lower()
        body_fat_percent = event.get('body_fat_percent', 0.12)

        # Validate using layer utilities
        if not validate_gender(gender):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid gender. Must be "male" or "female"'})
            }

        if not validate_activity_level(activity_level):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Invalid activity_level. Must be one of: {list(ACTIVITY_MULTIPLIERS.keys())}'})
            }

        if not validate_objective(objectif):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Invalid objectif. Must be one of: {list(OBJECTIF_CALORIES.keys())}'})
            }

        # Calculate BMI using layer utility
        bmi = calculate_bmi(weight_in_kg, height)
        bmi_category = get_bmi_category(bmi)

        # Your existing calculation logic here...
        # (Copy your BMR, TDEE, macro calculations from your original function)

        # Placeholder response
        response_data = {
            'message': 'Targets calculation with layer utilities',
            'bmi': bmi,
            'bmi_category': bmi_category,
            'layer_info': 'Using minimal targets layer',
            'note': 'Replace with your actual computeTargets logic'
        }

        return {
            'statusCode': 200,
            'body': json.dumps(response_data)
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
EOF
    echo "⚠️  Created placeholder targets Lambda - please add your actual computeTargets logic"
fi

if [ ! -f "lambda_functions/meal_optimizer/lambda_function.py" ]; then
    cat > lambda_functions/meal_optimizer/lambda_function.py << 'EOF'
import json
import os
import numpy as np
import polars as pl
from scipy.optimize import nnls
import boto3
from io import StringIO

def create_optimal_meals(event, context):
    """
    Meal optimizer using full scientific stack in container
    """
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Meal optimizer in container - full scipy available',
            'note': 'Replace with your actual meal optimization logic'
        })
    }
EOF
    echo "⚠️  Created placeholder meal optimizer - please add your actual optimization logic"
fi

echo ""
echo "📊 Summary:"
echo "   ✅ Targets layer: $(ls -lh layers/targets_layer.zip | awk '{print $5}')"
echo "   ✅ Container setup: Ready for meal optimizer"
echo "   📁 Directory structure:"
find lambda_functions -type f

echo ""
echo "🚀 Next steps:"
echo "1. Replace placeholder functions with your actual code"
echo "2. Use the container-based main.tf for deployment"
echo "3. Run deployment script"
