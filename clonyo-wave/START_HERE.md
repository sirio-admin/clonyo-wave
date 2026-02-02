# 🚀 Clonyo-Wave Step Function v2 - Quick Start

Benvenuto! Questa guida ti aiuterà a testare la Step Function v2 con le nuove Lambda functions.

## 📋 Cosa è stato preparato

✅ **Step Function v2** con 3 nuove Lambda:
- `session-manager-fn` - Gestione sessioni (30 min timeout)
- `topic-analyzer-fn` - Analisi topic conversazione
- `context-evaluator-fn` - Valutazione sufficienza contesto

✅ **Configurazione completa**:
- File `.env` con credenziali AWS e Knowledge Base ID
- Docker Compose per LocalStack
- Script di inizializzazione automatica
- Test payloads realistici

✅ **Script di test**:
- `prepare_local_sfn.py` - Genera definizione per LocalStack
- `run-test.sh` - Esegue test singoli
- `test-local-stepfunction.sh` - Test completo automatico

## 🎯 Setup Rapido (5 minuti)

### 1. Rendi eseguibili gli script

```bash
cd clonyo-wave
chmod +x *.sh *.py
```

### 2. Genera la definizione Step Function locale

```bash
# Genera definizione che usa Lambda reali con Bedrock
python3 prepare_local_sfn.py
```

### 3. Avvia LocalStack

```bash
# Avvia container Docker
docker-compose -f docker-compose.local.yml up -d

# Attendi inizializzazione (60 secondi)
echo "Waiting for LocalStack initialization..."
sleep 60
```

### 4. Verifica setup

```bash
# Verifica LocalStack attivo
curl http://localhost:4566/_localstack/health

# Verifica tabelle DynamoDB create
aws dynamodb list-tables \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1

# Verifica Step Function creata
aws stepfunctions list-state-machines \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1
```

### 5. Esegui il primo test

```bash
# Test con domanda semplice su ETF
./run-test.sh test-payloads/text/01-simple-question.json
```

## 📁 Struttura Progetto

```
clonyo-wave/
├── lambdas/                          # 7 Lambda functions
│   ├── session-manager-fn/           # NEW: Gestione sessioni
│   ├── topic-analyzer-fn/            # NEW: Analisi topic
│   ├── context-evaluator-fn/         # NEW: Valutazione contesto
│   ├── reply-strategy-fn/            # Strategia risposta
│   ├── generate-response-fn/         # Generazione risposta AI
│   ├── text-to-speech-fn/            # Text-to-speech
│   └── get-file-contents-fn/         # Recupero trascrizioni
│
├── test-payloads/                    # Payload di test
│   ├── text/                         # 5 scenari messaggi testo
│   └── audio/                        # 1 scenario audio (mock)
│
├── init-scripts/                     # Setup LocalStack
│   └── 01-setup.sh                   # Crea tabelle, Lambda, Step Function
│
├── prepare_local_sfn.py              # Genera definizione locale
├── run-test.sh                       # Esegue test singolo
├── test-local-stepfunction.sh        # Test automatico completo
├── docker-compose.local.yml          # Configurazione LocalStack
│
└── Documentazione/
    ├── START_HERE.md                 # ← Sei qui
    ├── LOCALSTACK_QUICKSTART.md      # Guida dettagliata LocalStack
    ├── INTEGRATION_GUIDE.md          # Guida integrazione
    └── test-payloads/README.md       # Documentazione payload
```

## 🧪 Test Disponibili

### Test Messaggi Testo

```bash
# 1. Domanda semplice su ETF (mode: text, complexity: 0.2-0.3)
./run-test.sh test-payloads/text/01-simple-question.json

# 2. Consulenza investimento complessa (mode: audio, complexity: 0.8-1.0)
./run-test.sh test-payloads/text/02-complex-investment.json

# 3. Follow-up su conversazione (mode: text, complexity: 0.2-0.3)
./run-test.sh test-payloads/text/03-followup-question.json

# 4. Small talk (mode: text, complexity: 0.1)
./run-test.sh test-payloads/text/04-small-talk.json

# 5. Confronto tecnico ETF (mode: text/audio, complexity: 0.5-0.7)
./run-test.sh test-payloads/text/05-technical-comparison.json
```

### Test Batch

```bash
# Testa tutti i payload di testo
for file in test-payloads/text/*.json; do
  echo "Testing: $file"
  ./run-test.sh "$file"
  sleep 5  # Pausa per evitare throttling Bedrock
done
```

## 🔍 Cosa Succede Durante il Test

1. **ManageSession** - Crea/recupera sessione utente (30 min timeout)
2. **Store meta** - Salva metadati messaggio in DynamoDB
3. **Evaluate type** - Determina se testo o audio
4. **Transform** - Normalizza input
5. **Store received** - Salva messaggio utente
6. **AnalyzeTopic** - Analizza topic con Claude Haiku
7. **Get History** - Recupera storico sessione
8. **Check Sufficiency** - Valuta se contesto è sufficiente
9. **Query KB** (se necessario) - Query Knowledge Base
10. **Get strategy** - Determina mode (text/audio) e complexity
11. **Generate response** - Genera risposta con Claude Sonnet + RAG
12. **Reply** - Invia risposta (mock su LocalStack)
13. **Store sent** - Salva risposta in DynamoDB
14. **Update session** - Aggiorna timestamp sessione

## 📊 Monitoraggio

### Visualizza execution history

```bash
# Ottieni ARN dall'output del test
EXECUTION_ARN="arn:aws:states:eu-west-1:000000000000:execution:..."

# Visualizza tutti gli eventi
aws stepfunctions get-execution-history \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --execution-arn "$EXECUTION_ARN" \
  --max-results 50
```

### Verifica dati DynamoDB

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

### Logs LocalStack

```bash
# Visualizza logs in real-time
docker-compose -f docker-compose.local.yml logs -f

# Solo errori
docker-compose -f docker-compose.local.yml logs -f | grep -i error
```

## ⚠️ Note Importanti

### Bedrock Reale
Le Lambda chiamano **AWS Bedrock reale** usando le credenziali nel file `.env`:
- Ogni test costa circa **$0.01-0.05**
- Consuma quota Bedrock del tuo account
- Richiede permessi: `bedrock:InvokeModel`, `bedrock-agent:Retrieve`

### Knowledge Base
Il Knowledge Base ID `PDZQMPE5HM` deve:
- Esistere nel tuo account AWS
- Essere nella region `eu-west-1`
- Contenere documenti indicizzati

### Rate Limiting
Attendi **3-5 secondi** tra test consecutivi per evitare throttling Bedrock.

## 🐛 Troubleshooting

### LocalStack non si avvia

```bash
# Verifica Docker
docker ps

# Riavvia
docker-compose -f docker-compose.local.yml down
docker-compose -f docker-compose.local.yml up -d
```

### Step Function non trovata

```bash
# Ricrea tutto
docker-compose -f docker-compose.local.yml restart

# Attendi 60 secondi
sleep 60
```

### Lambda falliscono

```bash
# Verifica logs
docker-compose -f docker-compose.local.yml logs localstack | grep -i error

# Verifica credenziali AWS
cat ../.env | grep AWS_ACCESS_KEY_ID
```

### Bedrock Throttling

```bash
# Riduci frequenza test
# Attendi 5-10 secondi tra esecuzioni
```

## 📚 Documentazione Completa

- **LOCALSTACK_QUICKSTART.md** - Guida dettagliata LocalStack
- **INTEGRATION_GUIDE.md** - Dettagli integrazione nuove Lambda
- **test-payloads/README.md** - Documentazione payload e scenari
- **STEP_FUNCTION_PIPELINE.md** - Documentazione completa pipeline

## 🎉 Prossimi Passi

1. ✅ Esegui test con payload di esempio
2. 🔄 Personalizza payload per i tuoi casi d'uso
3. 🔄 Analizza risultati e ottimizza configurazione
4. 🔄 Deploy su AWS production quando pronto

## 💡 Tips

- Usa `01-simple-question.json` per test rapidi
- Usa `02-complex-investment.json` per testare KB query
- Usa `04-small-talk.json` per testare context sufficiency
- Monitora costi Bedrock su AWS Console

## 🆘 Supporto

Se incontri problemi:
1. Controlla logs LocalStack
2. Verifica credenziali AWS nel `.env`
3. Verifica Knowledge Base esiste
4. Consulta INTEGRATION_GUIDE.md per dettagli

---

**Pronto per iniziare?** Esegui:

```bash
chmod +x *.sh *.py
python3 prepare_local_sfn.py
docker-compose -f docker-compose.local.yml up -d
sleep 60
./run-test.sh test-payloads/text/01-simple-question.json
```

Buon testing! 🚀
