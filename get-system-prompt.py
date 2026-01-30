#!/usr/bin/env python3
"""
Script per recuperare e visualizzare il system prompt da DynamoDB
"""

import boto3
import json
from decimal import Decimal

# Helper per convertire Decimal in float/int
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj) if obj % 1 else int(obj)
        return super().default(obj)

# Configurazione
TABLE_NAME = "sidea-ai-clone-prod-config-table"
REGION = "eu-west-1"

# Client DynamoDB
dynamodb = boto3.client('dynamodb', region_name=REGION)

print(f"📊 Recupero configurazione da: {TABLE_NAME}\n")

# Scan della tabella
response = dynamodb.scan(TableName=TABLE_NAME)

# Processa gli items
for item in response.get('Items', []):
    print("=" * 80)
    print(f"🔑 PK: {item.get('pk', {}).get('S', 'N/A')}")
    print(f"🔑 SK: {item.get('sk', {}).get('S', 'N/A')}")
    print("-" * 80)

    # Configurazione Bedrock
    if 'system_prompt' in item:
        system_prompt = item['system_prompt'].get('S', '')
        print(f"\n📝 SYSTEM PROMPT:\n")
        print(system_prompt)
        print("\n")

    if 'knowledge_base_id' in item:
        print(f"📚 Knowledge Base ID: {item['knowledge_base_id'].get('S', 'N/A')}")

    if 'retrieval_results' in item:
        print(f"🔢 Retrieval Results: {item['retrieval_results'].get('N', 'N/A')}")

    if 'temperature' in item:
        print(f"🌡️  Temperature: {item['temperature'].get('N', 'N/A')}")

    if 'max_tokens' in item:
        print(f"🎯 Max Tokens: {item['max_tokens'].get('N', 'N/A')}")

    print("=" * 80)
    print("\n")

print("✅ Recupero completato!")
