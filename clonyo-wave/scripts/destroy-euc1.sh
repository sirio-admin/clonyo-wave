#!/bin/bash
set -e

# Clonyo Wave - Destroy Test Environment
# This script destroys the entire test environment in eu-central-1

REGION="eu-central-1"
PROFILE="sirio"
LAMBDA_STACK="clonyo-wave-test-euc1-lambda"
INFRA_STACK="clonyo-wave-test-euc1-infra"
BUCKET="sidea-ai-clone-cfn-deploy-euc1"
MEDIA_BUCKET="sidea-ai-clone-test-euc1-wa-media-s3"

echo "⚠️  WARNING: This will delete the ENTIRE test environment in eu-central-1"
echo ""
echo "Stacks to delete:"
echo "  - $LAMBDA_STACK (7 Lambda functions)"
echo "  - $INFRA_STACK (DynamoDB tables, S3, IAM roles)"
echo ""
echo "S3 Buckets to empty and delete:"
echo "  - $MEDIA_BUCKET"
echo "  - $BUCKET"
echo ""
read -p "Are you absolutely sure? Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted"
  exit 0
fi

echo ""
echo "🗑️  Starting cleanup process..."

# Empty S3 buckets first (required before deletion)
echo "📦 Emptying S3 buckets..."
aws s3 rm "s3://$MEDIA_BUCKET" --recursive --region $REGION --profile $PROFILE 2>/dev/null || echo "  Media bucket already empty or doesn't exist"
aws s3 rm "s3://$BUCKET" --recursive --region $REGION --profile $PROFILE 2>/dev/null || echo "  Deployment bucket already empty or doesn't exist"

# Delete Lambda stack
echo "🗑️  Deleting Lambda Functions stack..."
aws cloudformation delete-stack \
  --stack-name $LAMBDA_STACK \
  --region $REGION \
  --profile $PROFILE 2>/dev/null || echo "  Lambda stack doesn't exist"

echo "  Waiting for Lambda stack deletion..."
aws cloudformation wait stack-delete-complete \
  --stack-name $LAMBDA_STACK \
  --region $REGION \
  --profile $PROFILE 2>/dev/null || echo "  Lambda stack deletion complete or already deleted"

# Delete Infrastructure stack
echo "🗑️  Deleting Infrastructure stack..."
aws cloudformation delete-stack \
  --stack-name $INFRA_STACK \
  --region $REGION \
  --profile $PROFILE 2>/dev/null || echo "  Infrastructure stack doesn't exist"

echo "  Waiting for Infrastructure stack deletion..."
aws cloudformation wait stack-delete-complete \
  --stack-name $INFRA_STACK \
  --region $REGION \
  --profile $PROFILE 2>/dev/null || echo "  Infrastructure stack deletion complete or already deleted"

# Delete S3 buckets
echo "🗑️  Deleting S3 buckets..."
aws s3 rb "s3://$MEDIA_BUCKET" --region $REGION --profile $PROFILE 2>/dev/null || echo "  Media bucket already deleted"
aws s3 rb "s3://$BUCKET" --region $REGION --profile $PROFILE 2>/dev/null || echo "  Deployment bucket already deleted"

echo ""
echo "✅ Environment destroyed successfully"
echo ""
echo "Remaining manual cleanup (if any):"
echo "  1. Check for any orphaned Step Functions"
echo "  2. Check CloudWatch Log Groups"
echo "  3. Verify no resources with 'test-euc1' pattern remain"
