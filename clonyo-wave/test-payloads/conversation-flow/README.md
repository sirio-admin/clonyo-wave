# Test Conversation Flow

Questa cartella contiene 7 payload per testare una conversazione completa con cambio di topic.

## Utente di test
- **wa_id**: `393331234567`
- **Nome**: Marco Rossi

## Flusso della conversazione

| # | File | Topic | Descrizione |
|---|------|-------|-------------|
| 1 | `01-saluto-investimenti.json` | Investimenti | Prima domanda sui fondi comuni |
| 2 | `02-followup-investimenti.json` | Investimenti | Seguito sulla stessa topic |
| 3 | `03-cambio-topic-assicurazione.json` | Assicurazione | **CAMBIO TOPIC** → polizza vita |
| 4 | `04-followup-assicurazione.json` | Assicurazione | Seguito su assicurazione |
| 5 | `05-cambio-topic-mutuo.json` | Mutuo | **CAMBIO TOPIC** → mutuo prima casa |
| 6 | `06-ritorno-investimenti.json` | Investimenti | **RITORNO** al topic iniziale (PAC) |
| 7 | `07-domanda-generica.json` | Generale | Domanda generica (orari filiale) |

## Come eseguire i test

### Eseguire un singolo payload
```bash
AWS_PROFILE=sirio aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:eu-central-1:533267110337:stateMachine:sidea-ai-clone-test-euc1-wa-message-processor-sfn \
  --input file://test-payloads/conversation-flow/01-saluto-investimenti.json \
  --region eu-central-1
```

### Eseguire tutti in sequenza
```bash
for f in test-payloads/conversation-flow/0*.json; do
  echo "Executing: $f"
  AWS_PROFILE=sirio aws stepfunctions start-execution \
    --state-machine-arn arn:aws:states:eu-central-1:533267110337:stateMachine:sidea-ai-clone-test-euc1-wa-message-processor-sfn \
    --input file://$f \
    --region eu-central-1
  sleep 5  # Attendi tra un'esecuzione e l'altra
done
```

## Controllare le tabelle DynamoDB

### Sessions Table
```bash
# Visualizza tutte le sessioni
AWS_PROFILE=sirio aws dynamodb scan \
  --table-name sidea-ai-clone-test-euc1-sessions-table \
  --region eu-central-1

# Cerca sessione specifica (se conosci il session_id)
AWS_PROFILE=sirio aws dynamodb get-item \
  --table-name sidea-ai-clone-test-euc1-sessions-table \
  --key '{"session_id": {"S": "SESSION_ID_QUI"}}' \
  --region eu-central-1
```

### Messages Table
```bash
# Visualizza tutti i messaggi
AWS_PROFILE=sirio aws dynamodb scan \
  --table-name sidea-ai-clone-test-euc1-messages-table \
  --region eu-central-1

# Cerca messaggi per un contatto specifico (pk contiene wa_id)
AWS_PROFILE=sirio aws dynamodb query \
  --table-name sidea-ai-clone-test-euc1-messages-table \
  --key-condition-expression "pk = :pk" \
  --expression-attribute-values '{":pk": {"S": "S#arn:aws:social-messaging:eu-central-1:533267110337:phone-number-id/test-phone-001#C#393331234567"}}' \
  --region eu-central-1
```

## Verificare l'esecuzione Step Function

### Lista ultime esecuzioni
```bash
AWS_PROFILE=sirio aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:eu-central-1:533267110337:stateMachine:sidea-ai-clone-test-euc1-wa-message-processor-sfn \
  --max-results 10 \
  --region eu-central-1
```

### Dettagli di un'esecuzione specifica
```bash
AWS_PROFILE=sirio aws stepfunctions describe-execution \
  --execution-arn EXECUTION_ARN_QUI \
  --region eu-central-1
```

### Storico eventi di un'esecuzione
```bash
AWS_PROFILE=sirio aws stepfunctions get-execution-history \
  --execution-arn EXECUTION_ARN_QUI \
  --region eu-central-1
```
