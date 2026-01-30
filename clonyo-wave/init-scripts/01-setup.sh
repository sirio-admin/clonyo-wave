#!/bin/bash
set -e

echo "Installing zip..."
apt-get update > /dev/null
apt-get install -y zip > /dev/null

echo "Creating DynamoDB Tables..."
awslocal dynamodb create-table \
    --table-name sidea-ai-clone-prod-sessions-table \
    --attribute-definitions \
        AttributeName=session_id,AttributeType=S \
        AttributeName=wa_contact_id,AttributeType=S \
    --key-schema AttributeName=session_id,KeyType=HASH \
    --global-secondary-indexes \
        "[
            {
                \"IndexName\": \"wa_contact_id_index\",
                \"KeySchema\": [{\"AttributeName\":\"wa_contact_id\",\"KeyType\":\"HASH\"}],
                \"Projection\": {\"ProjectionType\":\"ALL\"},
                \"ProvisionedThroughput\": {\"ReadCapacityUnits\": 5, \"WriteCapacityUnits\": 5}
            }
        ]" \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

awslocal dynamodb create-table \
    --table-name sidea-ai-clone-prod-messages-table \
    --attribute-definitions \
        AttributeName=pk,AttributeType=S \
        AttributeName=sk,AttributeType=S \
    --key-schema \
        AttributeName=pk,KeyType=HASH \
        AttributeName=sk,KeyType=RANGE \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

echo "Deploying Lambdas..."

DEPLOY_LAMBDA() {
    FUNCTION_NAME=$1
    HANDLER=$2
    FOLDER=$3
    
    echo "Deploying $FUNCTION_NAME..."
    cd /opt/lambdas/$FOLDER
    zip -r -q /tmp/$FUNCTION_NAME.zip . -x "vendor/*" # Exclude vendor to speed up if mounting, BUT we need vendor to run. Assuming vendor is present or we rely on layer.
    # Actually for local testing without layers, we need vendor.
    # Re-zipping with everything.
    zip -r -q /tmp/$FUNCTION_NAME.zip .
    
    awslocal lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime provided.al2 \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler $HANDLER \
        --zip-file fileb:///tmp/$FUNCTION_NAME.zip \
        --layers arn:aws:lambda:eu-west-1:209497400698:layer:php-82:16 
        # Note: Bref layers from real AWS won't work in LocalStack unless we mock them or use custom runtime image.
        # But we mounted 'bref/php-82' in pure docker-compose before? 
        # Wait, Step Functions calls lambda ARN. LocalStack spawns it. 
        # If we use Zip deployment in LocalStack, LocalStack uses 'lambda-executor' to run.
        # If executor is 'docker', it spins up a container. Which image? 
        # It detects runtime. 'provided.al2' uses amazonlinux.
        # To run PHP, we generally need the Bref layer.
        # In LocalStack, standard layers (ARN references) are mocked but content is not downloaded from AWS.
        # We need to either: 
        # A) Use valid LocalStack PRO feature for layers
        # B) Zip the 'bootstrap' binary from Bref into the zip.
        
}

# For LocalStack Open Source, layers are tricky.
# BETTER APPROACH for LocalStack + PHP:
# Use 'bref/php-82' image directly via docker-reuse or just ensuring 'bootstrap' is in the root of the zip.
# Bref puts 'bootstrap' in 'vendor/bin/bref-bootstrap' usually? 
# No, standard Bref deployment puts a bootstrap file.
# Since we are "implementing locally", ensuring `vendor` is there and valid `bootstrap` is key.
# If user ran `composer install`, `vendor/bin/bref-bootstrap` exists.
# We need to copy it to `bootstrap` in the root of the zip.

PREPARE_AND_DEPLOY() {
    FUNCTION_NAME=$1
    HANDLER=$2
    FOLDER=$3
    
    echo "Packaging $FUNCTION_NAME..."
    cd /opt/lambdas/$FOLDER
    
    # Check for vendor
    if [ ! -d "vendor" ]; then
        echo "WARNING: vendor directory missing in $FOLDER. Function might fail."
    fi
    
    # Copy bootstrap if needed (Bref structure)
    # Bref normally suggests using 'layers' for runtime. Without layers (LocalStack Community), we must include the runtime binary 'php' and 'bootstrap'.
    # This is complex to set up from scratch in a bash script without a build image.
    
    # SIMPLIFIED APPROACH:
    # We will assume for this PoC that we just upload the code. 
    # If execution fails due to missing runtime, we will debug.
    # But to make it work, usually we define Runtime: provided.al2 and user ensures environment is right.
    # Let's try to pass the handler.
    
    zip -r -q /tmp/$FUNCTION_NAME.zip .
    
    awslocal lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime provided.al2 \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler $HANDLER \
        --zip-file fileb:///tmp/$FUNCTION_NAME.zip \
        --environment "Variables={AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY,AWS_REGION=$AWS_REGION}"
}

PREPARE_AND_DEPLOY "session-manager-fn" "App\Handlers\SessionManagerHandler" "session-manager-fn"
PREPARE_AND_DEPLOY "topic-analyzer-fn" "App\Handlers\AnalyzeTopicHandler" "topic-analyzer-fn"
PREPARE_AND_DEPLOY "context-evaluator-fn" "App\Handlers\ContextEvaluatorHandler" "context-evaluator-fn"
# Existing
PREPARE_AND_DEPLOY "reply-strategy-fn" "App\Handlers\ReplyStrategyHandler" "reply-strategy-fn"
PREPARE_AND_DEPLOY "generate-response-fn" "App\Handlers\GenerateResponseHandler" "generate-response-fn"
PREPARE_AND_DEPLOY "text-to-speech-fn" "App\Handlers\TextToSpeechHandler" "text-to-speech-fn"
PREPARE_AND_DEPLOY "get-file-contents-fn" "App\Handlers\GetFileContentsHandler" "get-file-contents-fn"

echo "Creating Step Function..."
# Load definition from the mounted file
# We mount the whole project to /opt/lambdas in docker-compose.local.yml.
# So properties file is at /opt/lambdas/step-function-definition-local.json
awslocal stepfunctions create-state-machine \
    --name "sidea-ai-clone-prod-wa-message-processor-sfn" \
    --definition file:///opt/lambdas/step-function-definition-local.json \
    --role-arn "arn:aws:iam::000000000000:role/service-role/StepFunctionRole"

echo "Setup Complete!"
