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
