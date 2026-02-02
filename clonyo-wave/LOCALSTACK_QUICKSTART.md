# LocalStack QuickStart - Step Function v2

Guida rapida per testare la Step Function v2 con le nuove Lambda functions su LocalStack.

## Prerequisiti

- Docker e Docker Compose installati
- AWS CLI installato
- Python 3.x
- File `.env` configurato con credenziali AWS

## Setup Rapido

### 1. Verifica Credenziali

Assicurati che il file `.env` contenga:

```bash
# AWS Credentials (per chiamare Bedrock reale)
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_DEFAULT_REGION=eu-west-1

# AWS Bedrock Knowledge Base
KNOWLEDGE_BASE_ID=your_kb_id_here

# LocalStack endpoint
AWS_ENDPOINT_URL=http://localhost:4566
```

### 2. Scegli Modalità di Test

#### Opzione A: Test con Mock (Consigliato per iniziare)

Testa solo il flusso della Step Function senza chiamare servizi esterni:

```bash
cd clonyo-wave

# Genera definizione mockata
python3 prepare_local_sfn_mock.py

# Avvia LocalStack
docker-compose -f docker-compose.local.yml up -d

# Attendi inizializzazione (30-60 secondi)
sleep 60

# Verifica setup
curl http://localhost:4566/_localstack/health

# Esegui test
./test-local-stepfunction.sh
```

#### Opzione B: Test con Lambda Reali

Testa con Lambda che chiamano Bedrock reale (richiede AWS credentials valide):

```bash
cd clonyo-wave

# Usa definizione locale standard
python3 prepare_local_sfn.py

# Avvia LocalStack
docker-compose -f docker-compose.local.yml up -d

# Attendi inizializzazione
sleep 60

# Le Lambda chiameranno Bedrock su AWS reale
# Nota: Questo richiede che le Lambda abbiano accesso alle credenziali AWS
```

## Struttura Test

### Cosa viene testato

La Step Function v2 include questi nuovi step:

1. **ManageSession** - Gestisce sessioni conversazionali (30 min)
2. **AnalyzeTopic** - Analizza topic ed estrae keywords
3. **Get Session History** - Recupera storico filtrato per topic
4. **Check Sufficiency** - Valuta se contesto è sufficiente
5. **Query Static KB** - Query Knowledge Base se contesto insufficiente
6. **Update Session Meta** - Aggiorna timestamp sessione

### Input di Test

```json
{
  "wa_contact": {
    "wa_id": "393462454282",
    "profile": {"name": "Mario Rossi"}
  },
  "message_ts": 1738162800,
  "reply_to_wa_id": "393462454282",
  "config": {
    "wa_phone_number_arn": "arn:aws:test:eu-west-1:000000000000:phone/test",
    "response_generator": {
      "kb_id": "PDZQMPE5HM",
      "temperature": 0.5,
      "max_tokens": 4096
    },
    "text_to_speech": {
      "provider": "elevenlabs",
      "voice_id": "test-voice"
    }
  },
  "text": {
    "body": "Ciao, come funzionano gli ETF?"
  }
}
```

## Verifica Risultati

### 1. Controlla Status Esecuzione

```bash
# Lista esecuzioni
aws stepfunctions list-executions \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --state-machine-arn arn:aws:states:eu-west-1:000000000000:stateMachine:sidea-ai-clone-prod-wa-message-processor-sfn

# Dettagli esecuzione specifica
aws stepfunctions describe-execution \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --execution-arn <EXECUTION_ARN>
```

### 2. Verifica Dati DynamoDB

```bash
# Messaggi salvati
aws dynamodb scan \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --table-name sidea-ai-clone-prod-messages-table

# Sessioni create
aws dynamodb scan \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --table-name sidea-ai-clone-prod-sessions-table
```

### 3. Visualizza Execution History

```bash
aws stepfunctions get-execution-history \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --execution-arn <EXECUTION_ARN> \
  --max-results 50
```

## Troubleshooting

### LocalStack non si avvia

```bash
# Verifica logs
docker-compose -f docker-compose.local.yml logs -f

# Riavvia
docker-compose -f docker-compose.local.yml down
docker-compose -f docker-compose.local.yml up -d
```

### Step Function non trovata

```bash
# Verifica state machines
aws stepfunctions list-state-machines \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1

# Se mancante, ricrea
docker-compose -f docker-compose.local.yml restart
```

### Lambda falliscono

**Con Mock**: Non dovrebbe succedere, le Lambda sono sostituite da Pass states.

**Con Lambda Reali**: 
- Verifica che `vendor/` sia presente in ogni Lambda
- Verifica credenziali AWS nel container
- Controlla logs LocalStack

```bash
docker-compose -f docker-compose.local.yml logs localstack | grep -i error
```

### Bedrock Throttling

Se usi Lambda reali e ricevi throttling:

```bash
# Riduci retry nella Step Function
# Oppure attendi qualche minuto tra test
```

## Comandi Utili

### Reset Completo

```bash
# Ferma e rimuovi tutto
docker-compose -f docker-compose.local.yml down -v

# Riavvia
docker-compose -f docker-compose.local.yml up -d

# Attendi inizializzazione
sleep 60
```

### Logs in Real-Time

```bash
# Tutti i logs
docker-compose -f docker-compose.local.yml logs -f

# Solo errori
docker-compose -f docker-compose.local.yml logs -f | grep -i error
```

### Test Singoli Step

Puoi testare singoli step usando `step-function-test-local.json`:

```bash
# Testa solo i nuovi step (ManageSession, AnalyzeTopic, CheckSufficiency)
aws stepfunctions start-execution \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --state-machine-arn arn:aws:states:eu-west-1:000000000000:stateMachine:test-new-steps \
  --input file://step-function-test-local.json
```

## Differenze Mock vs Real

### Versione Mock (`prepare_local_sfn_mock.py`)

✅ **Pro:**
- Test velocissimi (< 5 secondi)
- Nessuna dipendenza esterna
- Nessun costo AWS
- Perfetto per testare logica Step Function

❌ **Contro:**
- Non testa Lambda reali
- Non testa integrazione Bedrock
- Risposte AI sono fisse

### Versione Real (`prepare_local_sfn.py`)

✅ **Pro:**
- Testa Lambda reali
- Testa integrazione Bedrock
- Risposte AI reali
- Test end-to-end completo

❌ **Contro:**
- Più lento (30-60 secondi)
- Richiede credenziali AWS valide
- Consuma quota Bedrock
- Setup più complesso

## Prossimi Passi

1. ✅ Test con mock per validare flusso
2. 🔄 Test con Lambda reali per validare AI
3. 🔄 Deploy su AWS production
4. 🔄 Monitoraggio e ottimizzazione

## Risorse

- [LocalStack Docs](https://docs.localstack.cloud/)
- [AWS Step Functions JSONata](https://docs.aws.amazon.com/step-functions/latest/dg/transforming-data.html)
- [Bedrock Knowledge Bases](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html)

## Note Importanti

⚠️ **Credenziali AWS**: Le credenziali nel file `.env` sono usate dalle Lambda per chiamare Bedrock. Assicurati che abbiano i permessi necessari:
- `bedrock:InvokeModel`
- `bedrock:Retrieve` (per Knowledge Base)

⚠️ **Knowledge Base**: L'ID `PDZQMPE5HM` deve esistere nel tuo account AWS e contenere documenti indicizzati.

⚠️ **Costi**: Ogni chiamata a Bedrock ha un costo. Usa la versione mock per test frequenti.
