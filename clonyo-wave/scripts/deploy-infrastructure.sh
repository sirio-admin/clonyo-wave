#!/bin/bash
set -e

# Clonyo Wave - Deploy Infrastructure Stack
# This script deploys DynamoDB tables, S3 bucket, and IAM roles

STACK_NAME="clonyo-wave-test-euc1-infra"
REGION="eu-central-1"
PROFILE="sirio"
ENVIRONMENT="test-euc1"
BEDROCK_KB_ID="YT2DL1CBQI"

# Safety check
if [ "$AWS_REGION" == "eu-west-1" ]; then
  echo "❌ ERROR: Cannot deploy to eu-west-1 (production region)"
  exit 1
fi

echo "🚀 Deploying Infrastructure Stack to eu-central-1"
echo "Stack name: $STACK_NAME"
echo "Environment: $ENVIRONMENT"
echo ""

# Deploy stack
aws cloudformation deploy \
  --template-file cloudformation/infrastructure.yaml \
  --stack-name $STACK_NAME \
  --parameter-overrides \
    Environment=$ENVIRONMENT \
    BedrockKBId=$BEDROCK_KB_ID \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION \
  --profile $PROFILE

echo ""
echo "✅ Infrastructure stack deployed successfully"
echo ""

# Get outputs
echo "📋 Stack Outputs:"
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table

echo ""
echo "Next step: Run ./scripts/deploy-lambdas.sh"
