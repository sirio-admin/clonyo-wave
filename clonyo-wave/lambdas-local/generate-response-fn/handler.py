import json
import os
import boto3
from datetime import datetime

# Initialize Bedrock client with real AWS credentials
bedrock_runtime = boto3.client(
    'bedrock-agent-runtime',
    region_name='eu-west-1',
    aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY')
)

bedrock = boto3.client(
    'bedrock-runtime',
    region_name='eu-west-1',
    aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY')
)

def handler(event, context):
    """
    Generate AI response using Bedrock + Knowledge Base
    Mimics the PHP Lambda behavior
    """
    print(f"Event: {json.dumps(event)}")
    
    try:
        # Extract input
        user_input = event.get('userInput', '')
        config = event.get('config', {})
        messages_key = event.get('messages_key', '')
        
        kb_id = config.get('kb_id', os.environ.get('KNOWLEDGE_BASE_ID', 'PDZQMPE5HM'))
        model_id = config.get('model_id', 'anthropic.claude-3-sonnet-20240229-v1:0')
        temperature = config.get('temperature', 0.5)
        max_tokens = config.get('max_tokens', 4096)
        system_prompt = config.get('system_prompt', 'Sei un assistente finanziario esperto.')
        
        # Get conversation history from DynamoDB (LocalStack)
        dynamodb = boto3.client(
            'dynamodb',
            endpoint_url='http://host.docker.internal:4566',
            region_name='eu-west-1'
        )
        
        history_response = dynamodb.query(
            TableName='sidea-ai-clone-prod-messages-table',
            KeyConditionExpression='pk = :pk',
            ExpressionAttributeValues={
                ':pk': {'S': messages_key}
            },
            ScanIndexForward=False,
            Limit=10
        )
        
        # Build conversation messages
        messages = []
        for item in reversed(history_response.get('Items', [])):
            if item.get('sk', {}).get('S', '').startswith('M#'):
                role = item.get('role', {}).get('S', 'user')
                content = item.get('content', {}).get('S', '')
                messages.append({
                    'role': role,
                    'content': content
                })
        
        # Add current user input
        messages.append({
            'role': 'user',
            'content': user_input
        })
        
        # Query Knowledge Base
        print(f"Querying Knowledge Base: {kb_id}")
        kb_response = bedrock_runtime.retrieve(
            knowledgeBaseId=kb_id,
            retrievalQuery={
                'text': user_input
            }
        )
        
        # Build context from KB results
        kb_context = ""
        if 'retrievalResults' in kb_response:
            for result in kb_response['retrievalResults'][:3]:  # Top 3 results
                if 'content' in result and 'text' in result['content']:
                    kb_context += result['content']['text'] + "\n\n"
        
        # Enhance system prompt with KB context
        enhanced_system = system_prompt
        if kb_context:
            enhanced_system += f"\n\nContesto dalla Knowledge Base:\n{kb_context}"
        
        # Call Bedrock
        print(f"Calling Bedrock model: {model_id}")
        bedrock_request = {
            'anthropic_version': 'bedrock-2023-05-31',
            'temperature': temperature,
            'max_tokens': max_tokens,
            'system': enhanced_system,
            'messages': messages
        }
        
        bedrock_response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps(bedrock_request)
        )
        
        response_body = json.loads(bedrock_response['body'].read())
        ai_response = response_body['content'][0]['text']
        
        print(f"Generated response: {ai_response[:100]}...")
        
        return {
            'statusCode': 200,
            'response': ai_response
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        raise e
