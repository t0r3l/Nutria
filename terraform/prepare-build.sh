#!/bin/bash

# Prepare build files for Terraform deployment
# This script ensures all required ZIP files exist before running Terraform

set -e

echo "=== Preparing Build Files for Terraform ==="

PROJECT_ROOT="$(dirname "$PWD")"
BUILDS_DIR="$PROJECT_ROOT/builds"
LAYERS_DIR="$PROJECT_ROOT/layers"
LAMBDA_FUNCTIONS_DIR="$PROJECT_ROOT/lambda_functions"

echo "Project root: $PROJECT_ROOT"

# Create directories if they don't exist
mkdir -p "$BUILDS_DIR" "$LAYERS_DIR"

# Check and create targets lambda ZIP if it doesn't exist
if [ ! -f "$BUILDS_DIR/targets_lambda.zip" ]; then
    echo "Creating targets_lambda.zip..."
    
    if [ -f "$LAMBDA_FUNCTIONS_DIR/targets/lambda_function.py" ]; then
        cd "$LAMBDA_FUNCTIONS_DIR/targets"
        zip -r "$BUILDS_DIR/targets_lambda.zip" . -x "*.pyc" "__pycache__/*"
        echo "✓ Created $BUILDS_DIR/targets_lambda.zip"
    else
        echo "⚠️  Warning: lambda_function.py not found, creating dummy zip"
        cd "$PROJECT_ROOT"
        echo "# Dummy Lambda function" > temp_lambda.py
        echo "def lambda_handler(event, context):" >> temp_lambda.py
        echo "    return {'statusCode': 200, 'body': 'Hello from Lambda'}" >> temp_lambda.py
        zip "$BUILDS_DIR/targets_lambda.zip" temp_lambda.py
        rm temp_lambda.py
        echo "✓ Created dummy $BUILDS_DIR/targets_lambda.zip"
    fi
else
    echo "✓ $BUILDS_DIR/targets_lambda.zip already exists"
fi

# Check and create layer ZIP if it doesn't exist
if [ ! -f "$LAYERS_DIR/targets_layer.zip" ]; then
    echo "Creating targets_layer.zip..."
    
    # Create a minimal layer with common Python packages
    TEMP_LAYER_DIR=$(mktemp -d)
    mkdir -p "$TEMP_LAYER_DIR/python"
    
    cd "$TEMP_LAYER_DIR"
    
    # Create requirements.txt for layer dependencies
    cat > requirements.txt << 'EOF'
numpy==1.24.3
requests==2.31.0
pandas==2.0.3
EOF
    
    # Install packages to python directory
    if command -v pip >/dev/null 2>&1; then
        echo "Installing layer dependencies..."
        pip install -r requirements.txt -t python/ --quiet || echo "⚠️  Failed to install dependencies"
    else
        echo "⚠️  pip not found, creating empty layer"
        echo "# Empty layer" > python/__init__.py
    fi
    
    # Create the ZIP
    zip -r "$LAYERS_DIR/targets_layer.zip" python/ --quiet
    cd "$PROJECT_ROOT"
    rm -rf "$TEMP_LAYER_DIR"
    
    echo "✓ Created $LAYERS_DIR/targets_layer.zip"
else
    echo "✓ $LAYERS_DIR/targets_layer.zip already exists"
fi

echo
echo "=== Build Preparation Complete ==="
echo "Files created:"
ls -lh "$BUILDS_DIR"/*.zip 2>/dev/null || echo "No build files"
ls -lh "$LAYERS_DIR"/*.zip 2>/dev/null || echo "No layer files"
echo
echo "You can now run: terraform plan -var-file=environments/dev/terraform.tfvars"