#!/bin/bash

# ============================================
# Test Step Function (eu-central-1)
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_PROFILE="sirio"
REGION="eu-central-1"
ENVIRONMENT="test-euc1"
STATE_MACHINE_NAME="sidea-ai-clone-${ENVIRONMENT}-wa-message-processor-sfn"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Step Function Execution${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get State Machine ARN
STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query "stateMachines[?name=='${STATE_MACHINE_NAME}'].stateMachineArn" \
    --output text)

if [ -z "$STATE_MACHINE_ARN" ]; then
    echo "Error: State Machine not found: ${STATE_MACHINE_NAME}"
    exit 1
fi

echo "State Machine: ${STATE_MACHINE_NAME}"
echo "ARN: ${STATE_MACHINE_ARN}"
echo ""

# Test Input
TEST_INPUT='{
  "wa_contact": {
    "wa_id": "393462454282",
    "profile": {
      "name": "Test User"
    }
  },
  "message_ts": 1738425600,
  "reply_to_wa_id": "393462454282",
  "text": {
    "body": "Ciao, vorrei informazioni sugli investimenti"
  },
  "config": {
    "wa_phone_number_arn": "test-phone-arn",
    "response_generator": {
      "kb_id": "YT2DL1CBQI",
      "model_id": "anthropic.claude-3-sonnet-20240229-v1:0",
      "temperature": 0.5,
      "max_tokens": 4096,
      "system_prompt": "Sei un assistente finanziario esperto."
    },
    "text_to_speech": {
      "voice_id": "test-voice-id",
      "model_id": "eleven_multilingual_v2"
    }
  }
}'

echo -e "${YELLOW}Starting execution...${NC}"
echo ""

# Start execution
EXECUTION_ARN=$(aws stepfunctions start-execution \
    --state-machine-arn "$STATE_MACHINE_ARN" \
    --name "test-$(date +%s)" \
    --input "$TEST_INPUT" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query 'executionArn' \
    --output text)

echo "Execution ARN: ${EXECUTION_ARN}"
echo ""
echo "Waiting for execution to complete..."

# Wait for completion
while true; do
    STATUS=$(aws stepfunctions describe-execution \
        --execution-arn "$EXECUTION_ARN" \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'status' \
        --output text)
    
    if [ "$STATUS" = "SUCCEEDED" ]; then
        echo -e "${GREEN}✓ Execution SUCCEEDED${NC}"
        break
    elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "TIMED_OUT" ] || [ "$STATUS" = "ABORTED" ]; then
        echo -e "\033[0;31m✗ Execution ${STATUS}${NC}"
        break
    else
        echo "Status: ${STATUS}..."
        sleep 5
    fi
done

echo ""
echo -e "${YELLOW}Execution Details:${NC}"
aws stepfunctions describe-execution \
    --execution-arn "$EXECUTION_ARN" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query '{Status:status,StartDate:startDate,StopDate:stopDate}' \
    --output table

echo ""
echo -e "${YELLOW}Execution Output:${NC}"
aws stepfunctions describe-execution \
    --execution-arn "$EXECUTION_ARN" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query 'output' \
    --output text | jq '.' 2>/dev/null || echo "No output or invalid JSON"

echo ""
echo "View full execution history:"
echo "aws stepfunctions get-execution-history --execution-arn ${EXECUTION_ARN} --region ${REGION} --profile ${AWS_PROFILE}"
echo ""
echo "View CloudWatch Logs:"
echo "aws logs tail /aws/states/${STATE_MACHINE_NAME} --follow --region ${REGION} --profile ${AWS_PROFILE}"
echo ""
