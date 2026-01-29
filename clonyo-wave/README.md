# Step Function: sidea-ai-clone-prod-wa-message-processor-sfn

## Informazioni Generali
- **Nome**: sidea-ai-clone-prod-wa-message-processor-sfn
- **ARN**: arn:aws:states:eu-west-1:533267110337:stateMachine:sidea-ai-clone-prod-wa-message-processor-sfn
- **Tipo**: STANDARD
- **Stato**: ACTIVE
- **Data Creazione**: 2025-06-01T14:21:35.801000+02:00
- **Region**: eu-west-1

## Lambda Functions Associate

### 1. sidea-ai-clone-prod-reply-strategy-fn
- **ARN**: arn:aws:lambda:eu-west-1:533267110337:function:sidea-ai-clone-prod-reply-strategy-fn
- **Scopo**: Determina la strategia di risposta (testo o audio) e il fattore di complessità
- **Directory**: `lambdas/reply-strategy-fn/`

### 2. sidea-ai-clone-prod-generate-response-fn
- **ARN**: arn:aws:lambda:eu-west-1:533267110337:function:sidea-ai-clone-prod-generate-response-fn
- **Scopo**: Genera la risposta basata sulla knowledge base
- **Directory**: `lambdas/generate-response-fn/`

### 3. sidea-ai-clone-prod-text-to-speech-fn
- **ARN**: arn:aws:lambda:eu-west-1:533267110337:function:sidea-ai-clone-prod-text-to-speech-fn
- **Scopo**: Converte il testo in audio per le risposte vocali
- **Directory**: `lambdas/text-to-speech-fn/`

### 4. sidea-ai-clone-prod-get-file-contents-fn
- **ARN**: arn:aws:lambda:eu-west-1:533267110337:function:sidea-ai-clone-prod-get-file-contents-fn
- **Scopo**: Recupera il contenuto dei file di trascrizione da Amazon Transcribe
- **Directory**: `lambdas/get-file-contents-fn/`

## Flusso della Step Function

1. **ExtractVariables**: Estrae le variabili dall'input
2. **Store WA message meta**: Salva i metadati del messaggio WhatsApp in DynamoDB
3. **Evaluate message type**: Valuta se il messaggio è testo o audio
   - Se testo → TransformForResponse
   - Se audio → StartTranscriptionJob (Amazon Transcribe)
4. **Store WA received message**: Salva il messaggio ricevuto in DynamoDB
5. **Get reply strategy**: Determina la strategia di risposta (Lambda)
6. **Build Knowledge based response**: Genera la risposta (Lambda)
7. **Choose output type**: Sceglie il tipo di output (testo o audio)
   - Se testo → Reply to WA User with text
   - Se audio → Generate audio from text (Lambda) → PostWhatsAppMessageMedia → Reply to WA User with media
8. **Store WA sent message**: Salva il messaggio inviato in DynamoDB
9. **Success**: Completamento con successo

## Risorse AWS Utilizzate

- **DynamoDB**: sidea-ai-clone-prod-messages-table
- **Amazon Transcribe**: Per la trascrizione dei messaggi vocali
- **AWS Social Messaging**: Per l'invio di messaggi WhatsApp
- **S3**: Per lo storage dei file audio

## File Scaricati

```
.
├── README.md
├── step-function-definition.json
└── lambdas/
    ├── generate-response-fn/
    │   └── [codice sorgente]
    ├── generate-response-fn-code.zip
    ├── generate-response-fn-config.json
    ├── get-file-contents-fn/
    │   └── [codice sorgente]
    ├── get-file-contents-fn-code.zip
    ├── get-file-contents-fn-config.json
    ├── reply-strategy-fn/
    │   └── [codice sorgente]
    ├── reply-strategy-fn-code.zip
    ├── reply-strategy-fn-config.json
    ├── text-to-speech-fn/
    │   └── [codice sorgente]
    ├── text-to-speech-fn-code.zip
    └── text-to-speech-fn-config.json
```
