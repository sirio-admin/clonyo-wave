#!/bin/bash
set -e

# Clonyo Wave - Test Pipeline Execution
# This script tests the complete Step Function pipeline with a sample payload

STACK_NAME="clonyo-wave-test-euc1"
REGION="eu-central-1"
PROFILE="sirio"
TEST_EVENT="test-events/euc1-text-message.json"

echo "🧪 Testing Clonyo Wave Pipeline..."
echo "Stack: $STACK_NAME"
echo "Region: $REGION"
echo "Test Event: $TEST_EVENT"
echo ""

# Get State Machine ARN from stack outputs
echo "📋 Retrieving State Machine ARN..."
STATE_MACHINE_ARN=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].Outputs[?OutputKey==`StateMachineArn`].OutputValue' \
  --output text)

if [ -z "$STATE_MACHINE_ARN" ]; then
  echo "❌ ERROR: Could not find State Machine ARN in stack outputs"
  exit 1
fi

echo "  State Machine: $STATE_MACHINE_ARN"
echo ""

# Start execution
echo "🚀 Starting Step Function execution..."
EXECUTION_ARN=$(aws stepfunctions start-execution \
  --state-machine-arn $STATE_MACHINE_ARN \
  --input file://$TEST_EVENT \
  --region $REGION \
  --profile $PROFILE \
  --query 'executionArn' \
  --output text)

echo "  Execution ARN: $EXECUTION_ARN"
echo ""
echo "⏳ Waiting for execution to complete (this may take 30-60 seconds)..."

# Wait for completion (with timeout)
TIMEOUT=120
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  STATUS=$(aws stepfunctions describe-execution \
    --execution-arn $EXECUTION_ARN \
    --region $REGION \
    --profile $PROFILE \
    --query 'status' \
    --output text)

  if [ "$STATUS" == "SUCCEEDED" ]; then
    echo ""
    echo "✅ Execution SUCCEEDED!"
    break
  elif [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "TIMED_OUT" ] || [ "$STATUS" == "ABORTED" ]; then
    echo ""
    echo "❌ Execution $STATUS"
    break
  fi

  echo -n "."
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

echo ""

# Get execution details
echo "📋 Execution Details:"
aws stepfunctions describe-execution \
  --execution-arn $EXECUTION_ARN \
  --region $REGION \
  --profile $PROFILE \
  --query '{Status:status,StartDate:startDate,StopDate:stopDate}' \
  --output table

# Get execution history (last 10 events)
echo ""
echo "📜 Execution History (last 10 events):"
aws stepfunctions get-execution-history \
  --execution-arn $EXECUTION_ARN \
  --region $REGION \
  --profile $PROFILE \
  --max-results 10 \
  --reverse-order \
  --query 'events[*].{Type:type,Timestamp:timestamp}' \
  --output table

# Check DynamoDB for stored messages
echo ""
echo "📊 Verifying data in DynamoDB..."
MESSAGES_TABLE="sidea-ai-clone-test-euc1-messages-table"
SESSIONS_TABLE="sidea-ai-clone-test-euc1-sessions-table"

echo "  Messages table:"
aws dynamodb scan \
  --table-name $MESSAGES_TABLE \
  --region $REGION \
  --profile $PROFILE \
  --max-items 3 \
  --query 'Items[*].{PK:pk.S,SK:sk.S,Role:role.S,Content:content.S}' \
  --output table || echo "    (No messages found or table doesn't exist)"

echo ""
echo "  Sessions table:"
aws dynamodb scan \
  --table-name $SESSIONS_TABLE \
  --region $REGION \
  --profile $PROFILE \
  --max-items 3 \
  --query 'Items[*].{SessionID:session_id.S,ContactID:wa_contact_id.S,Status:status.S}' \
  --output table || echo "    (No sessions found or table doesn't exist)"

echo ""
echo "🎉 Test Complete!"
echo ""
echo "To view logs:"
echo "  aws logs tail /aws/states/sidea-ai-clone-test-euc1-wa-message-processor-sfn --follow --region $REGION --profile $PROFILE"
