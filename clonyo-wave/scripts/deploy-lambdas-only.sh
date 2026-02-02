#!/bin/bash

# ============================================
# Deploy ONLY Lambda Functions (skip infrastructure)
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_PROFILE="sirio"
REGION="eu-central-1"
ENVIRONMENT="test-euc1"
LAMBDA_CODE_BUCKET="sidea-ai-clone-${ENVIRONMENT}-lambda-code"

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
echo -e "${GREEN}Deploy Lambda Functions Only${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

cd "$(dirname "$0")/.."

# Upload Lambda ZIPs
echo -e "${YELLOW}Uploading Lambda Functions to S3...${NC}"
for FUNCTION in "${LAMBDA_FUNCTIONS[@]}"; do
    echo "Uploading ${FUNCTION}.zip..."
    aws s3 cp "lambdas/${FUNCTION}.zip" \
        "s3://${LAMBDA_CODE_BUCKET}/lambdas/${FUNCTION}.zip" \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --quiet
    echo "✓ ${FUNCTION}.zip uploaded"
done

echo ""
echo -e "${YELLOW}Updating Lambda Functions...${NC}"

# Update each Lambda function
for FUNCTION in "${LAMBDA_FUNCTIONS[@]}"; do
    FUNCTION_NAME="sidea-ai-clone-${ENVIRONMENT}-${FUNCTION}"
    
    echo "Updating ${FUNCTION_NAME}..."
    
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --s3-bucket "$LAMBDA_CODE_BUCKET" \
        --s3-key "lambdas/${FUNCTION}.zip" \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --output json > /dev/null
    
    echo "✓ ${FUNCTION_NAME} updated"
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Lambda Functions Updated!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
