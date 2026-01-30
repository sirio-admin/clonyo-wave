#!/bin/bash
set -e

# Clonyo Wave - Deploy Lambda Functions Stack
# This script deploys all 7 Lambda functions

INFRA_STACK="clonyo-wave-test-euc1-infra"
STACK_NAME="clonyo-wave-test-euc1-lambda"
REGION="eu-central-1"
PROFILE="sirio"
ENVIRONMENT="test-euc1"
BUCKET="sidea-ai-clone-cfn-deploy-euc1"
BEDROCK_KB_ID="YT2DL1CBQI"

# Safety check
if [ "$AWS_REGION" == "eu-west-1" ]; then
  echo "❌ ERROR: Cannot deploy to eu-west-1 (production region)"
  exit 1
fi

echo "🚀 Deploying Lambda Functions Stack to eu-central-1"
echo "Stack name: $STACK_NAME"
echo "Lambda code bucket: $BUCKET"
echo ""

# Get infrastructure outputs
echo "📋 Retrieving infrastructure stack outputs..."
LAMBDA_ROLE=$(aws cloudformation describe-stacks \
  --stack-name $INFRA_STACK \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].Outputs[?OutputKey==`LambdaExecutionRoleArn`].OutputValue' \
  --output text)

MESSAGES_TABLE=$(aws cloudformation describe-stacks \
  --stack-name $INFRA_STACK \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].Outputs[?OutputKey==`MessagesTableName`].OutputValue' \
  --output text)

SESSIONS_TABLE=$(aws cloudformation describe-stacks \
  --stack-name $INFRA_STACK \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].Outputs[?OutputKey==`SessionsTableName`].OutputValue' \
  --output text)

CONFIG_TABLE=$(aws cloudformation describe-stacks \
  --stack-name $INFRA_STACK \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].Outputs[?OutputKey==`ConfigTableName`].OutputValue' \
  --output text)

MEDIA_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name $INFRA_STACK \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].Outputs[?OutputKey==`MediaBucketName`].OutputValue' \
  --output text)

echo "  Lambda Role: $LAMBDA_ROLE"
echo "  Messages Table: $MESSAGES_TABLE"
echo "  Sessions Table: $SESSIONS_TABLE"
echo "  Config Table: $CONFIG_TABLE"
echo "  Media Bucket: $MEDIA_BUCKET"
echo ""

# Deploy Lambda stack
echo "🚀 Deploying Lambda functions..."
aws cloudformation deploy \
  --template-file cloudformation/lambda-functions.yaml \
  --stack-name $STACK_NAME \
  --parameter-overrides \
    Environment=$ENVIRONMENT \
    LambdaCodeBucket=$BUCKET \
    LambdaExecutionRoleArn=$LAMBDA_ROLE \
    MessagesTableName=$MESSAGES_TABLE \
    SessionsTableName=$SESSIONS_TABLE \
    ConfigTableName=$CONFIG_TABLE \
    MediaBucketName=$MEDIA_BUCKET \
    BedrockKBId=$BEDROCK_KB_ID \
  --region $REGION \
  --profile $PROFILE

echo ""
echo "✅ Lambda functions stack deployed successfully"
echo ""

# Get Lambda ARNs
echo "📋 Lambda Function ARNs:"
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table

echo ""
echo "Next step: Create Step Function (manually or via AWS Console)"
echo "Then run: ./scripts/test-pipeline.sh"
