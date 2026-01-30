#!/bin/bash
set -e

# Prepare Step Function Definition for eu-central-1
# This script modifies the local definition for deployment

INPUT_FILE="step-function-definition-local.json"
OUTPUT_FILE="step-function-definition-euc1.json"
REGION="eu-central-1"
ACCOUNT_ID="533267110337"
ENVIRONMENT="test-euc1"

echo "🔧 Preparing Step Function definition for eu-central-1..."

# Create modified definition
cat "$INPUT_FILE" | \
  # Replace table names
  sed "s/sidea-ai-clone-prod-messages-table/sidea-ai-clone-$ENVIRONMENT-messages-table/g" | \
  sed "s/sidea-ai-clone-prod-sessions-table/sidea-ai-clone-$ENVIRONMENT-sessions-table/g" | \
  sed "s/sidea-ai-clone-prod-config-table/sidea-ai-clone-$ENVIRONMENT-config-table/g" | \
  # Replace Lambda ARNs (LocalStack placeholder)
  sed "s|eu-west-1:000000000000|$REGION:$ACCOUNT_ID|g" | \
  # Replace function names
  sed "s/function:reply-strategy-fn/function:sidea-ai-clone-$ENVIRONMENT-reply-strategy-fn/g" | \
  sed "s/function:generate-response-fn/function:sidea-ai-clone-$ENVIRONMENT-generate-response-fn/g" | \
  sed "s/function:text-to-speech-fn/function:sidea-ai-clone-$ENVIRONMENT-text-to-speech-fn/g" | \
  sed "s/function:get-file-contents-fn/function:sidea-ai-clone-$ENVIRONMENT-get-file-contents-fn/g" | \
  sed "s/function:session-manager-fn/function:sidea-ai-clone-$ENVIRONMENT-session-manager-fn/g" | \
  sed "s/function:topic-analyzer-fn/function:sidea-ai-clone-$ENVIRONMENT-topic-analyzer-fn/g" | \
  sed "s/function:context-evaluator-fn/function:sidea-ai-clone-$ENVIRONMENT-context-evaluator-fn/g" | \
  # Mock WhatsApp steps - Replace sendWhatsAppMessage with Pass
  sed 's|"Resource": "arn:aws:states:::aws-sdk:socialmessaging:sendWhatsAppMessage"|"Type": "Pass", "Comment": "MOCKED WhatsApp send"|g' | \
  sed 's|"Resource": "arn:aws:states:::aws-sdk:socialmessaging:postWhatsAppMessageMedia"|"Type": "Pass", "Comment": "MOCKED WhatsApp media post", "Result": {"MediaId": "mock-media-123"}|g' \
  > "$OUTPUT_FILE"

echo "✅ Definition prepared: $OUTPUT_FILE"
echo ""
echo "Changes applied:"
echo "  ✓ Table names: prod → $ENVIRONMENT"
echo "  ✓ Lambda ARNs: eu-west-1:000000000000 → $REGION:$ACCOUNT_ID"
echo "  ✓ Lambda names: Added $ENVIRONMENT prefix"
echo "  ✓ WhatsApp steps: Mocked (replaced with Pass states)"
