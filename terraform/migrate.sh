#!/bin/bash

# Migration script from old Terraform structure to new organized structure
# This script helps migrate your existing Terraform state to the new structure

set -e

echo "=== Nutria Terraform Migration Script ==="
echo "This script will help you migrate to the new Terraform structure"
echo

# Check if we're in the right directory
if [ ! -f "../main.tf" ]; then
    echo "Error: Please run this script from the terraform/ directory"
    exit 1
fi

# Prompt for environment
echo "Which environment are you migrating? (dev/staging/prod)"
read -p "Environment: " ENV

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Invalid environment. Choose dev, staging, or prod"
    exit 1
fi

echo
echo "=== Step 1: Backup current state ==="
if [ -f "../terraform.tfstate" ]; then
    echo "Backing up current state..."
    cp ../terraform.tfstate ../terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ State backed up"
else
    echo "No state file found. Proceeding..."
fi

echo
echo "=== Step 2: Prepare build files ==="
echo "Preparing Lambda deployment packages..."
./prepare-build.sh

echo
echo "=== Step 3: Initialize new structure ==="
echo "Initializing Terraform in new structure..."
terraform init

echo
echo "=== Step 4: Create workspace ==="
echo "Creating workspace for $ENV..."
terraform workspace new $ENV 2>/dev/null || terraform workspace select $ENV
echo "✓ Workspace '$ENV' selected"

echo
echo "=== Step 5: Import existing state (if needed) ==="
echo "If you have existing resources, you'll need to import them."
echo "This would require running terraform import commands for each resource."
echo

echo "=== Step 6: Plan with new structure ==="
echo "Running terraform plan to verify configuration..."
terraform plan -var-file=environments/$ENV/terraform.tfvars -out=tfplan

echo
echo "=== Migration Preparation Complete ==="
echo
echo "Next steps:"
echo "1. Review the plan output above"
echo "2. If you're migrating existing resources, you'll need to:"
echo "   - Copy the old terraform.tfstate to this directory"
echo "   - Run: terraform state pull > old-state.json"
echo "   - Manually update resource addresses if needed"
echo "3. When ready, apply the configuration:"
echo "   terraform apply tfplan"
echo
echo "For a fresh deployment (no existing resources):"
echo "   terraform apply -var-file=environments/$ENV/terraform.tfvars"
echo

# Create a helper script for common operations
cat > manage.sh << 'EOF'
#!/bin/bash
# Helper script for common Terraform operations

ENV=${1:-dev}
ACTION=${2:-plan}

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
    echo "Usage: ./manage.sh [dev|staging|prod] [plan|apply|destroy]"
    exit 1
fi

echo "Environment: $ENV"
echo "Action: $ACTION"

# Select workspace
terraform workspace select $ENV || terraform workspace new $ENV

# Run action
case $ACTION in
    plan)
        terraform plan -var-file=environments/$ENV/terraform.tfvars
        ;;
    apply)
        terraform apply -var-file=environments/$ENV/terraform.tfvars
        ;;
    destroy)
        terraform destroy -var-file=environments/$ENV/terraform.tfvars
        ;;
    *)
        echo "Unknown action: $ACTION"
        exit 1
        ;;
esac
EOF

chmod +x manage.sh

echo "Created manage.sh helper script for easier operations"