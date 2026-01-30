#!/bin/bash

# Script per recuperare il system prompt da DynamoDB

TABLE_NAME="sidea-ai-clone-prod-config-table"
REGION="eu-west-1"

echo "Recupero configurazione da DynamoDB..."
aws dynamodb scan \
    --table-name $TABLE_NAME \
    --region $REGION \
    --output json | jq -r '.Items[] | {
        pk: .pk.S,
        sk: .sk.S,
        system_prompt: .system_prompt.S,
        temperature: .temperature.N,
        max_tokens: .max_tokens.N,
        knowledge_base_id: .knowledge_base_id.S
    }'
