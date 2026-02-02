#!/usr/bin/env python3
"""
Script per creare una versione mockata della Step Function v2 per LocalStack.
Sostituisce tutte le chiamate Lambda e servizi esterni con Pass states.
"""

import json

def load_local_definition():
    """Carica la definizione locale creata da prepare_local_sfn.py"""
    with open('step-function-definition-local.json', 'r') as f:
        return json.load(f)

def save_mock_definition(def_json):
    """Salva la definizione mockata"""
    with open('step-function-definition-local-mock.json', 'w') as f:
        json.dump(def_json, f, indent=4)

def mock_lambda_states(states):
    """Sostituisce le chiamate Lambda con Pass states mockati"""
    
    # 1. ManageSession - Mock
    states['ManageSession'] = {
        "Type": "Pass",
        "Comment": "MOCKED: Returns fake session data",
        "Result": {
            "session_id": "mock-session-12345",
            "topic_id": None,
            "is_new_session": True
        },
        "ResultPath": "$.sessionResult",
        "Next": "Store WA message meta",
        "Assign": {
            "session_id": "{% $states.result.session_id %}",
            "current_topic_id": "{% $states.result.topic_id %}"
        }
    }
    
    # 2. AnalyzeTopic - Mock
    states['AnalyzeTopic'] = {
        "Type": "Pass",
        "Comment": "MOCKED: Returns fake topic analysis",
        "Result": {
            "topic_id": "finance-etf-123",
            "topic_name": "Finanza - ETF",
            "keywords": ["ETF", "investimenti", "fondi"]
        },
        "ResultPath": "$.topicResult",
        "Next": "Get Session History",
        "Assign": {
            "topic_id": "{% $states.result.topic_id %}",
            "topic_keywords": "{% $states.result.keywords %}"
        }
    }
    
    # 3. Check Sufficiency - Mock (sempre insufficient per testare KB query)
    states['Check Sufficiency'] = {
        "Type": "Pass",
        "Comment": "MOCKED: Returns insufficient to test KB path",
        "Result": {
            "sufficient": False
        },
        "ResultPath": "$.sufficiencyResult",
        "Next": "Is Sufficient?",
        "Assign": {
            "is_sufficient": "{% $states.result.sufficient %}"
        }
    }
    
    # 4. Query Static KB - Mock (sostituisce Bedrock Agent Runtime)
    states['Query Static KB'] = {
        "Type": "Pass",
        "Comment": "MOCKED: Returns fake KB documents",
        "Result": {
            "RetrievalResults": [
                {
                    "content": {"text": "Gli ETF (Exchange Traded Funds) sono fondi indicizzati quotati in borsa..."},
                    "score": 0.95,
                    "location": {"s3Location": {"uri": "s3://mock-kb/etf-guide.pdf"}}
                },
                {
                    "content": {"text": "Per investire in ETF è necessario aprire un conto titoli..."},
                    "score": 0.87,
                    "location": {"s3Location": {"uri": "s3://mock-kb/investing-guide.pdf"}}
                }
            ]
        },
        "ResultPath": "$.kbResult",
        "Next": "Get reply strategy",
        "Assign": {
            "kb_docs": "{% $states.result.RetrievalResults %}"
        }
    }
    
    # 5. Get reply strategy - Mock
    states['Get reply strategy'] = {
        "Type": "Pass",
        "Comment": "MOCKED: Returns text mode with medium complexity",
        "Result": {
            "mode": "text",
            "complexity_factor": 0.6
        },
        "ResultPath": "$.strategyResult",
        "Next": "Build Knowledge based response",
        "Assign": {
            "output_message_type": "{% $states.result.mode %}",
            "complexity_factor": "{% $states.result.complexity_factor %}"
        }
    }
    
    # 6. Build Knowledge based response - Mock
    states['Build Knowledge based response'] = {
        "Type": "Pass",
        "Comment": "MOCKED: Returns fake AI response",
        "Result": {
            "response": "Gli ETF sono fondi indicizzati che replicano l'andamento di un indice di mercato. Per investire in ETF, ti consiglio di: 1) Aprire un conto titoli presso una banca o broker online, 2) Identificare gli ETF più adatti al tuo profilo di rischio, 3) Considerare ETF ad accumulazione per beneficiare dell'interesse composto."
        },
        "ResultPath": "$.responseResult",
        "Next": "Choose output type",
        "Assign": {
            "output_message_content": "{% $states.result.response %}"
        }
    }
    
    # 7. Generate audio from text - Mock (se mai chiamato)
    if 'Generate audio from text' in states:
        states['Generate audio from text'] = {
            "Type": "Pass",
            "Comment": "MOCKED: Returns fake S3 audio path",
            "Result": {
                "bucket_name": "mock-bucket",
                "key": "mock-audio/response-123.ogg"
            },
            "Next": "PostWhatsAppMessageMedia"
        }
    
    # 8. Get transcript file content - Mock (per audio input)
    if 'Get transcript file content' in states:
        states['Get transcript file content'] = {
            "Type": "Pass",
            "Comment": "MOCKED: Returns fake transcript",
            "Result": {
                "content": json.dumps({
                    "results": {
                        "transcripts": [
                            {"transcript": "Ciao, vorrei sapere come investire in ETF"}
                        ]
                    }
                })
            },
            "Next": "TransformForResponse",
            "Output": {
                "transcript": "{% $parse($states.result.content).results.transcripts[0].transcript %}"
            }
        }
    
    return states

def mock_whatsapp_states(states):
    """Sostituisce le chiamate WhatsApp con Pass states"""
    
    # Reply to WA User with text
    if 'Reply to WA User with text' in states:
        states['Reply to WA User with text'] = {
            "Type": "Pass",
            "Comment": "MOCKED: Simulates WhatsApp text message sent",
            "Result": {
                "MessageId": "wamid.mock-123456",
                "Status": "sent"
            },
            "Next": "Store WA sent message"
        }
    
    # PostWhatsAppMessageMedia
    if 'PostWhatsAppMessageMedia' in states:
        states['PostWhatsAppMessageMedia'] = {
            "Type": "Pass",
            "Comment": "MOCKED: Simulates media upload to WhatsApp",
            "Result": {
                "MediaId": "wamid.mock-media-789"
            },
            "Next": "Reply to WA User with media"
        }
    
    # Reply to WA User with media
    if 'Reply to WA User with media' in states:
        states['Reply to WA User with media'] = {
            "Type": "Pass",
            "Comment": "MOCKED: Simulates WhatsApp audio message sent",
            "Result": {
                "MessageId": "wamid.mock-audio-456",
                "Status": "sent"
            },
            "Next": "Store WA sent message"
        }
    
    return states

def mock_transcribe_states(states):
    """Sostituisce Amazon Transcribe con mock più veloce"""
    
    # StartTranscriptionJob
    if 'StartTranscriptionJob' in states:
        states['StartTranscriptionJob'] = {
            "Type": "Pass",
            "Comment": "MOCKED: Simulates transcription job started",
            "Result": {
                "TranscriptionJob": {
                    "TranscriptionJobName": "mock-job-123",
                    "TranscriptionJobStatus": "IN_PROGRESS"
                }
            },
            "Next": "Wait for job to complete",
            "Assign": {
                "transcriptionJobName": "{% $states.result.TranscriptionJob.TranscriptionJobName %}"
            }
        }
    
    # Wait - Riduci a 1 secondo per test più veloci
    if 'Wait for job to complete' in states:
        states['Wait for job to complete']['Seconds'] = 1
    
    # GetTranscriptionJob
    if 'GetTranscriptionJob' in states:
        states['GetTranscriptionJob'] = {
            "Type": "Pass",
            "Comment": "MOCKED: Returns completed transcription job",
            "Result": {
                "TranscriptionJob": {
                    "TranscriptionJobName": "mock-job-123",
                    "TranscriptionJobStatus": "COMPLETED",
                    "Transcript": {
                        "TranscriptFileUri": "https://mock-transcribe.s3.amazonaws.com/transcript.json"
                    }
                }
            },
            "Next": "Job finished?"
        }
    
    return states

def transform_to_mock(def_json):
    """Applica tutte le trasformazioni mock"""
    states = def_json['States']
    
    print("Applying Lambda mocks...")
    states = mock_lambda_states(states)
    
    print("Applying WhatsApp mocks...")
    states = mock_whatsapp_states(states)
    
    print("Applying Transcribe mocks...")
    states = mock_transcribe_states(states)
    
    # Mantieni DynamoDB operations (LocalStack le supporta)
    # Mantieni Pass states esistenti
    
    def_json['States'] = states
    def_json['Comment'] = "Clone AI state machine - MOCKED VERSION for LocalStack testing"
    
    return def_json

def main():
    print("Loading local definition...")
    definition = load_local_definition()
    
    print("Transforming to mock version...")
    mock_def = transform_to_mock(definition)
    
    print("Saving mock definition...")
    save_mock_definition(mock_def)
    
    print("✅ Mock definition created: step-function-definition-local-mock.json")
    print("\nThis version:")
    print("  - Mocks all Lambda functions with Pass states")
    print("  - Mocks WhatsApp API calls")
    print("  - Mocks Bedrock/Transcribe calls")
    print("  - Keeps DynamoDB operations (LocalStack supports them)")
    print("\nYou can now test the Step Function flow without external dependencies!")

if __name__ == "__main__":
    main()
