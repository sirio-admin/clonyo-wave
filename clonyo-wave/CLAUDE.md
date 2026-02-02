# Clonyo Wave - WhatsApp AI Clone Agent

## Overview

Sistema di AI conversazionale per WhatsApp Business che gestisce sessioni, topic e contesto storico per fornire risposte intelligenti e contestualizzate.

## Architettura

```
┌─────────────────┐     ┌──────────────────────────────────────────────────────────┐
│  WhatsApp User  │────▶│              AWS Step Functions                          │
└─────────────────┘     │                                                          │
                        │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
                        │  │ ManageSession│──▶│ AnalyzeTopic │──▶│ Store Message│  │
                        │  └──────────────┘   └──────────────┘   └──────────────┘  │
                        │         │                  │                  │          │
                        │         ▼                  ▼                  ▼          │
                        │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
                        │  │ Get History  │──▶│Check Suffic. │──▶│ Query KB     │  │
                        │  └──────────────┘   └──────────────┘   └──────────────┘  │
                        │         │                  │                  │          │
                        │         ▼                  ▼                  ▼          │
                        │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
                        │  │Reply Strategy│──▶│Gen Response  │──▶│ Send Reply   │  │
                        │  └──────────────┘   └──────────────┘   └──────────────┘  │
                        └──────────────────────────────────────────────────────────┘
```

## Componenti

### Step Function: `sidea-ai-clone-test-euc1-wa-message-processor-sfn`

Orchestratore principale che gestisce il flusso di elaborazione messaggi.

**Flusso:**
1. `ExtractVariables` - Estrae variabili dal payload (wa_contact_id, config, etc.)
2. `ManageSession` - Crea/recupera sessione per l'utente
3. `Store WA message meta` - Salva metadata del contatto
4. `Evaluate message type` - Determina se testo o audio
5. `TransformForResponse` - Prepara input per elaborazione
6. `AnalyzeTopic` - Analizza e determina il topic del messaggio
7. `Store WA received message` - Salva messaggio utente con session_topic_key
8. `Get Session History` - Recupera storico messaggi per session+topic
9. `Check Sufficiency` - Valuta se serve KB o basta lo storico
10. `Query Static KB` - (opzionale) Interroga Knowledge Base Bedrock
11. `Get reply strategy` - Determina strategia di risposta (text/audio)
12. `Build Knowledge based response` - Genera risposta con LLM
13. `Reply to WA User` - Invia risposta (mock per ora)
14. `Store WA sent message` - Salva risposta assistant
15. `Update Session Meta` - Aggiorna metadata sessione

### Lambda Functions

| Lambda | Scopo |
|--------|-------|
| `session-manager-fn` | Gestisce creazione/recupero sessioni |
| `topic-analyzer-fn` | Analizza testo e determina topic_id |
| `context-evaluator-fn` | Valuta se lo storico è sufficiente |
| `reply-strategy-fn` | Decide modalità risposta (text/audio) |
| `generate-response-fn` | Genera risposta con Claude via Bedrock |
| `text-to-speech-fn` | Converte testo in audio (ElevenLabs) |
| `get-file-contents-fn` | Recupera contenuti da S3/URL |

### DynamoDB Tables

#### Messages Table: `sidea-ai-clone-test-euc1-messages-table`

Memorizza tutti i messaggi (user e assistant).

| Attributo | Tipo | Descrizione |
|-----------|------|-------------|
| `pk` (PK) | String | `S#<wa_phone_number_arn>#C#<wa_contact_id>` |
| `sk` (SK) | String | `META` oppure `M#<timestamp>` |
| `session_topic_key` | String | `<session_id>#<topic_id>` - per GSI |
| `role` | String | `user` o `assistant` |
| `content` | String | Contenuto del messaggio |
| `session_id` | String | ID sessione |
| `topic_id` | String | ID topic |

**GSI: `session-topic-index`**
- PK: `session_topic_key`
- SK: `sk`
- Projection: ALL

#### Sessions Table: `sidea-ai-clone-test-euc1-sessions-v2-table`

Traccia combinazioni sessione+topic per utente.

| Attributo | Tipo | Descrizione |
|-----------|------|-------------|
| `pk` (PK) | String | `<wa_contact_id>` |
| `sk` (SK) | String | `S#<session_id>#T#<topic_id>` |
| `session_id` | String | ID sessione |
| `topic_id` | String | ID topic |
| `last_active_at` | Number | Timestamp ultima attività |

## Logica di Contesto

Il sistema implementa una logica di recupero contesto intelligente:

1. **Stesso utente + Stessa sessione + Stesso topic** → Recupera storico conversazione
2. **Check Sufficiency** → Valuta se rispondere con lo storico o serve KB
3. **Knowledge Base** → Interroga Bedrock KB se serve più contesto

```
User: "Info sui fondi"     → Topic: investments, Session: abc123
User: "Quali rendimenti?"  → Topic: investments, Session: abc123
                             ↓
                           Get Session History query:
                           session_topic_key = "abc123#investments"
                             ↓
                           Recupera messaggi precedenti sullo stesso topic
```

## Esecuzione Test

### Eseguire un test
```bash
AWS_PROFILE=sirio aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:eu-central-1:533267110337:stateMachine:sidea-ai-clone-test-euc1-wa-message-processor-sfn \
  --input file://test-payloads/test-01-prima-domanda.json \
  --region eu-central-1
```

### Verificare Messages Table
```bash
AWS_PROFILE=sirio aws dynamodb scan \
  --table-name sidea-ai-clone-test-euc1-messages-table \
  --region eu-central-1
```

### Query per session+topic specifico
```bash
AWS_PROFILE=sirio aws dynamodb query \
  --table-name sidea-ai-clone-test-euc1-messages-table \
  --index-name session-topic-index \
  --key-condition-expression "session_topic_key = :stk" \
  --expression-attribute-values '{":stk": {"S": "SESSION_ID#TOPIC_ID"}}' \
  --region eu-central-1
```

### Verificare Sessions Table
```bash
AWS_PROFILE=sirio aws dynamodb query \
  --table-name sidea-ai-clone-test-euc1-sessions-v2-table \
  --key-condition-expression "pk = :pk" \
  --expression-attribute-values '{":pk": {"S": "393331234567"}}' \
  --region eu-central-1
```

## Deploy

### Infrastructure
```bash
AWS_PROFILE=sirio aws cloudformation deploy \
  --template-file cloudformation/infrastructure.yaml \
  --stack-name clonyo-wave-test-euc1-infrastructure \
  --region eu-central-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step Function
```bash
# Upload definition to S3
AWS_PROFILE=sirio aws s3 cp step-function-definition-euc1.json \
  s3://sidea-ai-clone-test-euc1-wa-media-s3/ --region eu-central-1

# Deploy stack
AWS_PROFILE=sirio aws cloudformation deploy \
  --template-file cloudformation/step-function.yaml \
  --stack-name clonyo-wave-test-euc1-step-function \
  --region eu-central-1 \
  --parameter-overrides \
    DefinitionS3Key=step-function-definition-euc1.json \
    ... (altri parametri)
```

## Configurazione

### Payload di Input

```json
{
  "wa_contact": {
    "wa_id": "393331234567",
    "profile": { "name": "Nome Utente" }
  },
  "message_ts": 1738350000,
  "reply_to_wa_id": "393331234567",
  "text": { "body": "Testo del messaggio" },
  "config": {
    "wa_phone_number_arn": "arn:...",
    "kb_id": "BEDROCK_KB_ID",
    "response_generator": {
      "model_id": "anthropic.claude-3-sonnet-...",
      "system_prompt": "..."
    }
  }
}
```

## Stati Mock (TODO)

I seguenti stati sono attualmente mock e devono essere implementati:

- `Reply to WA User with text` - Invio messaggio WhatsApp
- `PostWhatsAppMessageMedia` - Upload media WhatsApp
- `Reply to WA User with media` - Invio audio WhatsApp

Resource da usare: `arn:aws:states:::aws-sdk:socialmessaging:sendWhatsAppMessage`
