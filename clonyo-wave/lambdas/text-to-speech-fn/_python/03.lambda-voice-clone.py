import json
import boto3
import requests
import os
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    # Configurazione
    ELEVENLABS_API_KEY = os.environ['ELEVENLABS_API_KEY']
    VOICE_ID = os.environ['VOICE_ID']  # ID della voce da utilizzare
    S3_BUCKET = os.environ['S3_BUCKET']  # Nome del bucket S3
    
    try:
        # URL ElevenLabs
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}/stream"
        url += "?optimize_streaming_latency=0&output_format=mp3_22050_32"
        
        # Preparazione payload
        payload = {
            "text": event.get('text', ''),  # Testo da convertire
            "voice_settings": {
                "stability": 0.48,
                "similarity_boost": 0.5,
                "style": 0.78
            }
        }
        
        # Headers per la richiesta
        headers = {
            'Content-Type': 'application/json',
            'xi-api-key': ELEVENLABS_API_KEY
        }
        
        # Chiamata API ElevenLabs
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        
        # Nome file audio (puoi personalizzarlo)
        audio_file = f"audio_{context.aws_request_id}.mp3"
        
        # Upload su S3
        s3 = boto3.client('s3')
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=audio_file,
            Body=response.content,
            ContentType='audio/mpeg'
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Audio generato e salvato con successo',
                'file': audio_file,
                'bucket': S3_BUCKET
            })
        }
        
    except requests.exceptions.RequestException as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Errore nella chiamata a ElevenLabs',
                'details': str(e)
            })
        }
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Errore nel salvataggio su S3',
                'details': str(e)
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Errore generico',
                'details': str(e)
            })
        }