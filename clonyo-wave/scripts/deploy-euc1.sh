#!/bin/bash

# ============================================
# Deploy Clonyo Wave Test Environment (eu-central-1)
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_PROFILE="sirio"
REGION="eu-central-1"
ENVIRONMENT="test-euc1"
ACCOUNT_ID="533267110337"
BEDROCK_KB_ID="YT2DL1CBQI"

# S3 Buckets
LAMBDA_CODE_BUCKET="sidea-ai-clone-${ENVIRONMENT}-lambda-code"
TEMPLATES_BUCKET="sidea-ai-clone-${ENVIRONMENT}-cloudformation"

# Stack Names
MAIN_STACK_NAME="sidea-ai-clone-${ENVIRONMENT}-main"

# Lambda Functions
LAMBDA_FUNCTIONS=(
    "session-manager-fn"
    "topic-analyzer-fn"
    "context-evaluator-fn"
    "reply-strategy-fn"
    "generate-response-fn"
    "text-to-speech-fn"
    "get-file-contents-fn"
)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Clonyo Wave Test Deployment (eu-central-1)${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "AWS Profile: ${AWS_PROFILE}"
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${REGION}"
echo "Account: ${ACCOUNT_ID}"
echo ""

# ============================================
# Step 1: Create S3 Buckets if not exist
# ============================================

echo -e "${YELLOW}[1/5] Checking S3 Buckets...${NC}"

for BUCKET in "$LAMBDA_CODE_BUCKET" "$TEMPLATES_BUCKET"; do
    if aws s3 ls "s3://${BUCKET}" --region "$REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
        echo "✓ Bucket ${BUCKET} exists"
    else
        echo "Creating bucket ${BUCKET}..."
        aws s3 mb "s3://${BUCKET}" --region "$REGION" --profile "$AWS_PROFILE"
        echo "✓ Bucket ${BUCKET} created"
    fi
done

echo ""

# ============================================
# Step 2: Package Lambda Functions
# ============================================

echo -e "${YELLOW}[2/5] Packaging Lambda Functions...${NC}"

# Run packaging script
./scripts/package-lambdas-euc1.sh

echo ""

# ============================================
# Step 3: Upload Lambda ZIPs to S3
# ============================================

echo -e "${YELLOW}[3/5] Uploading Lambda Functions to S3...${NC}"

for FUNCTION in "${LAMBDA_FUNCTIONS[@]}"; do
    echo "Uploading ${FUNCTION}.zip..."
    aws s3 cp "lambdas/${FUNCTION}.zip" \
        "s3://${LAMBDA_CODE_BUCKET}/lambdas/${FUNCTION}.zip" \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --quiet
    echo "✓ ${FUNCTION}.zip uploaded"
done

# Upload Step Function definition
echo "Uploading step-function-definition-euc1.json..."
aws s3 cp "step-function-definition-euc1.json" \
    "s3://${LAMBDA_CODE_BUCKET}/step-function-definition-euc1.json" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --quiet
echo "✓ Step Function definition uploaded"

echo ""

# ============================================
# Step 4: Upload CloudFormation Templates
# ============================================

echo -e "${YELLOW}[4/5] Uploading CloudFormation Templates...${NC}"

for TEMPLATE in cloudformation/*.yaml; do
    TEMPLATE_NAME=$(basename "$TEMPLATE")
    echo "Uploading ${TEMPLATE_NAME}..."
    aws s3 cp "$TEMPLATE" \
        "s3://${TEMPLATES_BUCKET}/cloudformation/${TEMPLATE_NAME}" \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --quiet
    echo "✓ ${TEMPLATE_NAME} uploaded"
done

echo ""

# ============================================
# Step 5: Deploy CloudFormation Stack
# ============================================

echo -e "${YELLOW}[5/5] Deploying CloudFormation Stack...${NC}"

# Check if stack exists
if aws cloudformation describe-stacks \
    --stack-name "$MAIN_STACK_NAME" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    > /dev/null 2>&1; then
    
    echo "Stack exists, updating..."
    OPERATION="update-stack"
    WAIT_CONDITION="stack-update-complete"
else
    echo "Stack does not exist, creating..."
    OPERATION="create-stack"
    WAIT_CONDITION="stack-create-complete"
fi

aws cloudformation "$OPERATION" \
    --stack-name "$MAIN_STACK_NAME" \
    --template-url "https://${TEMPLATES_BUCKET}.s3.${REGION}.amazonaws.com/cloudformation/main.yaml" \
    --parameters \
        ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
        ParameterKey=BedrockKBId,ParameterValue="$BEDROCK_KB_ID" \
        ParameterKey=LambdaCodeBucket,ParameterValue="$LAMBDA_CODE_BUCKET" \
        ParameterKey=TemplatesBucket,ParameterValue="$TEMPLATES_BUCKET" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    --profile "$AWS_PROFILE"

echo "Waiting for stack operation to complete..."
aws cloudformation wait "$WAIT_CONDITION" \
    --stack-name "$MAIN_STACK_NAME" \
    --region "$REGION" \
    --profile "$AWS_PROFILE"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================
# Display Outputs
# ============================================

echo "Stack Outputs:"
aws cloudformation describe-stacks \
    --stack-name "$MAIN_STACK_NAME" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

echo ""
echo -e "${GREEN}✓ All resources deployed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure DynamoDB config table with phone number settings"
echo "2. Test Step Function with: aws stepfunctions start-execution ..."
echo "3. Monitor CloudWatch Logs for execution details"
echo ""
