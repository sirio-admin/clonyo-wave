#!/bin/bash
set -e

echo "=== LocalStack Initialization Started ==="

echo "Creating DynamoDB Tables..."

# Sessions table
awslocal dynamodb create-table \
    --table-name sidea-ai-clone-prod-sessions-table \
    --attribute-definitions AttributeName=session_id,AttributeType=S \
    --key-schema AttributeName=session_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    2>/dev/null || echo "Sessions table already exists"

echo "✓ Sessions table ready"

# Messages table
awslocal dynamodb create-table \
    --table-name sidea-ai-clone-prod-messages-table \
    --attribute-definitions \
        AttributeName=pk,AttributeType=S \
        AttributeName=sk,AttributeType=S \
    --key-schema \
        AttributeName=pk,KeyType=HASH \
        AttributeName=sk,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    2>/dev/null || echo "Messages table already exists"

echo "✓ Messages table ready"

# Config table (for runtime configuration)
awslocal dynamodb create-table \
    --table-name sidea-ai-clone-prod-config-table \
    --attribute-definitions AttributeName=wa_phone_number_arn,AttributeType=S \
    --key-schema AttributeName=wa_phone_number_arn,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    2>/dev/null || echo "Config table already exists"

echo "✓ Config table ready"

echo "Creating S3 Bucket..."
awslocal s3 mb s3://sidea-ai-clone-prod-wa-media-s3 2>/dev/null || echo "Bucket already exists"
echo "✓ S3 bucket ready"

echo "Deploying Lambda Functions with Hot Reload..."

# Deploy Lambda functions using hot-reload magic bucket
# This mounts the local code directly into the Lambda container

# 1. reply-strategy-fn
awslocal lambda create-function \
    --function-name reply-strategy-fn \
    --runtime provided.al2 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler App\\Handlers\\ReplyStrategyHandler \
    --code S3Bucket="hot-reload",S3Key="/opt/lambdas/reply-strategy-fn" \
    --environment "Variables={AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY,AWS_REGION=eu-west-1,KNOWLEDGE_BASE_ID=$KNOWLEDGE_BASE_ID}" \
    --timeout 30 \
    --memory-size 1024 \
    2>/dev/null || echo "reply-strategy-fn already exists"

# 2. generate-response-fn
awslocal lambda create-function \
    --function-name generate-response-fn \
    --runtime provided.al2 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler App\\Handlers\\GenerateResponseHandler \
    --code S3Bucket="hot-reload",S3Key="/opt/lambdas/generate-response-fn" \
    --environment "Variables={AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY,AWS_REGION=eu-west-1,KNOWLEDGE_BASE_ID=$KNOWLEDGE_BASE_ID}" \
    --timeout 30 \
    --memory-size 1024 \
    2>/dev/null || echo "generate-response-fn already exists"

# 3. text-to-speech-fn
awslocal lambda create-function \
    --function-name text-to-speech-fn \
    --runtime provided.al2 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler App\\Handlers\\TextToSpeechHandler \
    --code S3Bucket="hot-reload",S3Key="/opt/lambdas/text-to-speech-fn" \
    --environment "Variables={AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY,AWS_REGION=eu-west-1}" \
    --timeout 60 \
    --memory-size 1024 \
    2>/dev/null || echo "text-to-speech-fn already exists"

# 4. get-file-contents-fn
awslocal lambda create-function \
    --function-name get-file-contents-fn \
    --runtime provided.al2 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler App\\Handlers\\GetFileContentsHandler \
    --code S3Bucket="hot-reload",S3Key="/opt/lambdas/get-file-contents-fn" \
    --environment "Variables={AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY,AWS_REGION=eu-west-1}" \
    --timeout 10 \
    --memory-size 1024 \
    2>/dev/null || echo "get-file-contents-fn already exists"

echo "✓ Lambda functions deployed with hot-reload"

echo "Creating Step Function..."
# Use the local definition with LocalStack Lambda ARNs
DEFINITION_FILE="/opt/project/step-function-definition-local.json"

if [ ! -f "$DEFINITION_FILE" ]; then
    echo "ERROR: $DEFINITION_FILE not found"
    exit 1
fi

awslocal stepfunctions create-state-machine \
    --name "sidea-ai-clone-prod-wa-message-processor-sfn" \
    --definition file://$DEFINITION_FILE \
    --role-arn "arn:aws:iam::000000000000:role/service-role/StepFunctionRole" \
    2>/dev/null || echo "Step Function already exists"

echo "✓ Step Function ready"

echo ""
echo "=== Setup Complete ===" 
echo ""
echo "Available resources:"
echo "  • DynamoDB Tables: sidea-ai-clone-prod-messages-table, sidea-ai-clone-prod-sessions-table, sidea-ai-clone-prod-config-table"
echo "  • S3 Bucket: sidea-ai-clone-prod-wa-media-s3"
echo "  • Lambda Functions: reply-strategy-fn, generate-response-fn, text-to-speech-fn, get-file-contents-fn (with hot-reload)"
echo "  • Step Function: sidea-ai-clone-prod-wa-message-processor-sfn"
echo ""
echo "⚠️  NOTE: PHP Lambda functions require Bref runtime. LocalStack Community may have limitations."
echo "    If Lambda execution fails, consider using LocalStack Pro or Python wrapper functions."
echo ""
echo "Test with: ./run-test.sh test-payloads/text/01-simple-question.json"
echo ""
