# Guida Integrazione Step Function v2 con LocalStack

## Panoramica

La Step Function v2 integra 3 nuove Lambda functions per gestione sessioni, analisi topic e valutazione contesto:

1. **session-manager-fn** - Gestisce sessioni conversazionali (30 min timeout)
2. **topic-analyzer-fn** - Analizza topic ed estrae keywords
3. **context-evaluator-fn** - Valuta se il contesto è sufficiente per rispondere

## Nuovo Flusso

```
ExtractVariables
  ↓
ManageSession (NEW) ← Crea/recupera session_id
  ↓
Store WA message meta
  ↓
Evaluate message type (text/audio)
  ↓
TransformForResponse
  ↓
Store WA received message (con session_id, topic_id)
  ↓
AnalyzeTopic (NEW) ← Analizza topic conversazione
  ↓
Get Session History (NEW) ← Recupera storico filtrato per topic
  ↓
Check Sufficiency (NEW) ← Valuta se contesto è sufficiente
  ↓
Is Sufficient? (Choice)
  ├─ Yes → Get reply strategy
  └─ No → Query Static KB (NEW) → Get reply strategy
  ↓
Build Knowledge based response
  ↓
Choose output type (text/audio)
  ↓
Reply to WA User
  ↓
Store WA sent message (con session_id, topic_id)
  ↓
Update Session Meta (NEW) ← Aggiorna last_active_at
  ↓
Success
```

## Problemi da Risolvere per LocalStack

### 1. Runtime PHP in LocalStack

**Problema**: LocalStack Community non supporta nativamente i Bref layers di AWS.

**Soluzioni possibili**:

#### Opzione A: Mock delle Lambda (Consigliata per test rapidi)
Sostituire le chiamate Lambda con Pass states che restituiscono dati mock:

```json
"ManageSession": {
  "Type": "Pass",
  "Result": {
    "session_id": "mock-session-123",
    "topic_id": null,
    "is_new_session": true
  },
  "ResultPath": "$.sessionResult",
  "Next": "Store WA message meta",
  "Assign": {
    "session_id": "{% $states.result.session_id %}",
    "current_topic_id": "{% $states.result.topic_id %}"
  }
}
```

#### Opzione B: LocalStack Pro con Lambda Hot Reloading
Usare LocalStack Pro che supporta meglio i custom runtimes.

#### Opzione C: Container PHP Custom
Creare un'immagine Docker con PHP + Bref runtime e usarla per le Lambda.

### 2. Bedrock in LocalStack

**Problema**: LocalStack Community non supporta AWS Bedrock.

**Soluzioni**:

#### Per topic-analyzer-fn e context-evaluator-fn:
Queste Lambda chiamano Bedrock (Claude Haiku). Opzioni:

1. **Mock le Lambda** (come Opzione A sopra)
2. **Configurare AWS credentials reali** nel container LocalStack per chiamare Bedrock su AWS reale
3. **Usare LocalStack Pro** con Bedrock emulation

### 3. BedrockAgentRuntime:Retrieve

**Problema**: Lo state "Query Static KB" usa `bedrockagentruntime:retrieve` che non è supportato in LocalStack Community.

**Soluzione**: Sostituire con Pass state mock:

```json
"Query Static KB": {
  "Type": "Pass",
  "Result": {
    "RetrievalResults": [
      {
        "content": {"text": "Mock KB document content"},
        "score": 0.95
      }
    ]
  },
  "ResultPath": "$.kbResult",
  "Next": "Get reply strategy",
  "Assign": {
    "kb_docs": "{% $states.result.RetrievalResults %}"
  }
}
```

### 4. DynamoDB Sessions Table

**Problema**: La tabella `sidea-ai-clone-prod-sessions-table` deve esistere.

**Soluzione**: ✅ Già implementato in `init-scripts/01-setup.sh`

### 5. WhatsApp Social Messaging

**Problema**: LocalStack non supporta `socialmessaging` service.

**Soluzione**: Sostituire con Pass states per test:

```json
"Reply to WA User with text": {
  "Type": "Pass",
  "Result": {
    "MessageId": "mock-msg-id",
    "Status": "sent"
  },
  "Next": "Store WA sent message"
}
```

## Setup Rapido per Test LocalStack

### Step 1: Creare versione "mock" della Step Function

Creare `step-function-definition-local-mock.json` con tutte le chiamate esterne mockate:

```bash
cd clonyo-wave
python prepare_local_sfn_mock.py
```

### Step 2: Avviare LocalStack

```bash
docker-compose -f docker-compose.local.yml up -d
```

### Step 3: Verificare risorse create

```bash
# Verifica tabelle DynamoDB
aws dynamodb list-tables --endpoint-url http://localhost:4566 --region eu-west-1

# Verifica Lambda functions
aws lambda list-functions --endpoint-url http://localhost:4566 --region eu-west-1

# Verifica Step Function
aws stepfunctions list-state-machines --endpoint-url http://localhost:4566 --region eu-west-1
```

### Step 4: Testare Step Function

```bash
# Esegui con input di test
aws stepfunctions start-execution \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --state-machine-arn arn:aws:states:eu-west-1:000000000000:stateMachine:sidea-ai-clone-prod-wa-message-processor-sfn \
  --input '{
    "wa_contact": {
      "wa_id": "393462454282",
      "profile": {"name": "Test User"}
    },
    "message_ts": 1738162800,
    "reply_to_wa_id": "393462454282",
    "config": {
      "wa_phone_number_arn": "arn:aws:test",
      "response_generator": {
        "kb_id": "test-kb",
        "temperature": 0.5
      },
      "text_to_speech": {}
    },
    "text": {
      "body": "Ciao, come funzionano gli ETF?"
    }
  }'
```

### Step 5: Monitorare esecuzione

```bash
# Ottieni execution ARN dall'output del comando precedente
EXECUTION_ARN="arn:aws:states:eu-west-1:000000000000:execution:sidea-ai-clone-prod-wa-message-processor-sfn:..."

# Controlla status
aws stepfunctions describe-execution \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --execution-arn $EXECUTION_ARN

# Ottieni history
aws stepfunctions get-execution-history \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --execution-arn $EXECUTION_ARN
```

## Raccomandazioni

### Per Test Completi (con AI reale)

1. **Usare LocalStack Pro** - Supporta meglio custom runtimes e servizi AWS avanzati
2. **Configurare AWS credentials reali** - Per chiamare Bedrock su AWS mentre il resto gira su LocalStack
3. **Hybrid approach** - Step Function su LocalStack, Lambda su AWS reale

### Per Test Rapidi (solo flusso)

1. **Mockare tutte le Lambda** - Usare Pass states con dati fissi
2. **Focus su logica Step Function** - Testare routing, Choice states, variable management
3. **Validare JSONata expressions** - Assicurarsi che le trasformazioni dati funzionino

## Prossimi Passi

1. ✅ Definizione Step Function v2 creata
2. ✅ Script inizializzazione LocalStack pronto
3. ⚠️ **Decidere approccio**: Mock vs Real Lambda
4. 🔄 Creare script `prepare_local_sfn_mock.py` per versione completamente mockata
5. 🔄 Testare esecuzione end-to-end
6. 🔄 Documentare risultati e problemi riscontrati

## File Coinvolti

- `step-function-definition.json` - Definizione production (AWS reale)
- `step-function-definition-local.json` - Definizione per LocalStack (già creata)
- `prepare_local_sfn.py` - Script che genera la versione locale
- `init-scripts/01-setup.sh` - Setup iniziale LocalStack
- `docker-compose.local.yml` - Configurazione LocalStack
- `step-function-test-local.json` - Input test semplificato

## Domande da Risolvere

1. **Vuoi testare con Lambda reali o mockate?**
   - Mock = più veloce, solo test flusso
   - Reali = più complesso, test completo con AI

2. **Hai LocalStack Pro?**
   - Si = supporto migliore per custom runtimes
   - No = dobbiamo mockare di più

3. **Vuoi chiamare Bedrock reale da LocalStack?**
   - Si = configurare AWS credentials nel container
   - No = mockare anche le risposte AI
