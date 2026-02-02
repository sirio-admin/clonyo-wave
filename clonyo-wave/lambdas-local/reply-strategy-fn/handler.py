import json
import os
import boto3

# Initialize Bedrock client with real AWS credentials
bedrock = boto3.client(
    'bedrock-runtime',
    region_name='eu-west-1',
    aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY')
)

def handler(event, context):
    """
    Determine reply strategy (text/audio) and complexity factor
    Mimics the PHP Lambda behavior
    """
    print(f"Event: {json.dumps(event)}")
    
    try:
        user_input = event.get('userInput', '')
        original_input_type = event.get('original_input_type', 'text')
        
        # Simple strategy prompt
        strategy_prompt = f"""Analizza questo messaggio e determina:
1. Se la risposta dovrebbe essere testuale o audio (considera che l'utente ha inviato un messaggio {original_input_type})
2. La complessità della domanda (1-5, dove 5 è molto complessa)

Messaggio: {user_input}

Rispondi SOLO con un JSON in questo formato:
{{"mode": "text", "complexity_factor": 3}}"""
        
        # Call Bedrock with Claude 3.5 Sonnet
        bedrock_request = {
            'anthropic_version': 'bedrock-2023-05-31',
            'temperature': 0.3,
            'max_tokens': 200,
            'messages': [{
                'role': 'user',
                'content': strategy_prompt
            }]
        }
        
        response = bedrock.invoke_model(
            modelId='eu.anthropic.claude-3-5-sonnet-20240620-v1:0',
            body=json.dumps(bedrock_request)
        )
        
        response_body = json.loads(response['body'].read())
        ai_response = response_body['content'][0]['text']
        
        # Parse JSON response
        # Extract JSON from response (might have markdown code blocks)
        if '```json' in ai_response:
            ai_response = ai_response.split('```json')[1].split('```')[0].strip()
        elif '```' in ai_response:
            ai_response = ai_response.split('```')[1].split('```')[0].strip()
        
        strategy = json.loads(ai_response)
        
        print(f"Strategy: {strategy}")
        
        return {
            'statusCode': 200,
            'mode': strategy.get('mode', 'text'),
            'complexity_factor': strategy.get('complexity_factor', 3)
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        # Default fallback
        return {
            'statusCode': 200,
            'mode': 'text',
            'complexity_factor': 3
        }
