# cleanup_and_fix.sh
# This script cleans up existing resources and fixes layer issues

set -e

echo "🧹 Cleaning up existing AWS resources..."

# Delete existing IAM role and policies
echo "Cleaning up IAM resources..."
aws iam detach-role-policy --role-name nutria-lambda-execution-role-dev --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam delete-role-policy --role-name nutria-lambda-execution-role-dev --policy-name nutria-lambda-s3-policy-dev 2>/dev/null || true
aws iam delete-role --role-name nutria-lambda-execution-role-dev 2>/dev/null || true

# Delete existing log groups
echo "Cleaning up CloudWatch log groups..."
aws logs delete-log-group --log-group-name /aws/lambda/nutria-compute-targets-dev 2>/dev/null || true
aws logs delete-log-group --log-group-name /aws/lambda/nutria-meal-optimizer-dev 2>/dev/null || true

echo "✅ Cleanup completed"

echo ""
echo "🔧 Rebuilding layers with fixes..."

# Clean up old layers
rm -rf layers temp_* 2>/dev/null || true
