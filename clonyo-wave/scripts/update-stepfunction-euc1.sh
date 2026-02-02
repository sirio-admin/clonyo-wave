#!/bin/bash

# ============================================
# Update Step Function Definition
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_PROFILE="sirio"
REGION="eu-central-1"
ENVIRONMENT="test-euc1"
STATE_MACHINE_NAME="sidea-ai-clone-${ENVIRONMENT}-wa-message-processor-sfn"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Update Step Function${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

cd "$(dirname "$0")/.."

# Get State Machine ARN
STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query "stateMachines[?name=='${STATE_MACHINE_NAME}'].stateMachineArn" \
    --output text)

if [ -z "$STATE_MACHINE_ARN" ]; then
    echo "Error: State Machine not found: ${STATE_MACHINE_NAME}"
    echo "You need to create it first with CloudFormation"
    exit 1
fi

echo "State Machine: ${STATE_MACHINE_NAME}"
echo "ARN: ${STATE_MACHINE_ARN}"
echo ""

# Read definition file
DEFINITION=$(cat step-function-definition-euc1.json)

echo -e "${YELLOW}Updating Step Function definition...${NC}"

aws stepfunctions update-state-machine \
    --state-machine-arn "$STATE_MACHINE_ARN" \
    --definition "$DEFINITION" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --output json > /dev/null

echo ""
echo -e "${GREEN}✓ Step Function updated successfully!${NC}"
echo ""
echo "Test the Step Function:"
echo "./scripts/test-stepfunction-euc1.sh"
echo ""
