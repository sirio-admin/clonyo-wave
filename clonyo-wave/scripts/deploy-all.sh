#!/bin/bash
set -e

# Clonyo Wave - Deploy Complete Stack
# This script deploys the entire environment using nested CloudFormation stacks

STACK_NAME="clonyo-wave-test-euc1"
REGION="eu-central-1"
PROFILE="sirio"
ENVIRONMENT="test-euc1"
BEDROCK_KB_ID="YT2DL1CBQI"
BUCKET="sidea-ai-clone-cfn-deploy-euc1"

# Safety check
if [ "$AWS_REGION" == "eu-west-1" ]; then
  echo "❌ ERROR: Cannot deploy to eu-west-1 (production region)"
  exit 1
fi

echo "🚀 Deploying Complete Clonyo Wave Stack to eu-central-1"
echo "Stack name: $STACK_NAME"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo ""

# Verify bucket exists
if ! aws s3 ls "s3://$BUCKET" --region $REGION --profile $PROFILE 2>/dev/null; then
  echo "❌ ERROR: Deployment bucket s3://$BUCKET not found"
  echo "Run ./scripts/package-lambdas.sh first!"
  exit 1
fi

echo "📋 Pre-flight checks..."
echo "  ✓ AWS Profile: $PROFILE"
echo "  ✓ Deployment bucket: s3://$BUCKET"
echo "  ✓ Target region: $REGION"
echo ""

# Deploy main stack (nested)
echo "🚀 Deploying main CloudFormation stack..."
echo "This will create:"
echo "  1. Infrastructure Stack (DynamoDB, S3, IAM)"
echo "  2. Lambda Functions Stack (7 functions)"
echo "  3. Step Function Stack (Message Processor)"
echo ""

aws cloudformation deploy \
  --template-file cloudformation/main.yaml \
  --stack-name $STACK_NAME \
  --parameter-overrides \
    Environment=$ENVIRONMENT \
    BedrockKBId=$BEDROCK_KB_ID \
    LambdaCodeBucket=$BUCKET \
    TemplatesBucket=$BUCKET \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --region $REGION \
  --profile $PROFILE

echo ""
echo "✅ Complete stack deployed successfully!"
echo ""

# Get all outputs
echo "📋 Stack Outputs:"
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table

echo ""
echo "🎉 Deployment Complete!"
echo ""
echo "Next steps:"
echo "  1. Verify resources in AWS Console"
echo "  2. Run test execution: ./scripts/test-pipeline.sh"
echo "  3. Monitor CloudWatch Logs for any issues"
