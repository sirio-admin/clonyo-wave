# Test Payloads per Step Function v2

Questa cartella contiene payload di test realistici per testare la Step Function con Bedrock reale.

## Struttura

```
test-payloads/
├── text/           # Messaggi di testo
│   ├── 01-simple-question.json          # Domanda semplice su ETF
│   ├── 02-complex-investment.json       # Consulenza investimento complessa
│   ├── 03-followup-question.json        # Follow-up su conversazione
│   ├── 04-small-talk.json               # Small talk (test mode=text)
│   └── 05-technical-comparison.json     # Confronto tecnico prodotti
└── audio/          # Messaggi audio (mock)
    └── 01-audio-simple.json             # Messaggio audio mock

```

## Payload Structure

Ogni payload contiene:

### Campi Obbligatori

```json
{
  "wa_contact": {
    "wa_id": "393462454282",           // WhatsApp ID utente
    "profile": {
      "name": "Nome Utente"             // Nome profilo
    }
  },
  "message_ts": 1738162800,             // Unix timestamp
  "reply_to_wa_id": "393462454282",     // ID destinatario risposta
  "config": {
    "wa_phone_number_arn": "arn:...",   // ARN phone number
    "response_generator": {
      "provider": "bedrock",
      "kb_id": "PDZQMPE5HM",            // Knowledge Base ID
      "system_prompt": "...",            // System prompt per Claude
      "retrieval_results": 4,            // Numero documenti KB
      "temperature": 0.5,                // Temperature (0-1)
      "max_tokens": 4096                 // Max tokens risposta
    },
    "text_to_speech": {
      "provider": "elevenlabs",
      "voice_id": "pNInz6obpgDQGcFmaJgB",
      "output_format": "opus_48000_32",
      "stability": 0.76,
      "similarity_boost": 0.88
    }
  }
}
```

### Per Messaggi Testo

```json
{
  "text": {
    "body": "Il tuo messaggio qui"
  }
}
```

### Per Messaggi Audio

```json
{
  "audio": {
    "s3_uri": "s3://bucket/path/to/audio.ogg",
    "mime_type": "audio/ogg; codecs=opus"
  }
}
```

## Come Usare

### Test Singolo

```bash
# Testa con un payload specifico
./run-test.sh text/01-simple-question.json
```

### Test Multipli

```bash
# Testa tutti i payload di testo
for file in test-payloads/text/*.json; do
  echo "Testing: $file"
  ./run-test.sh "$file"
  sleep 5  # Attendi tra test per evitare throttling
done
```

### Test con LocalStack

```bash
cd clonyo-wave

# 1. Genera definizione locale
python3 prepare_local_sfn.py

# 2. Avvia LocalStack
docker-compose -f docker-compose.local.yml up -d

# 3. Attendi inizializzazione
sleep 60

# 4. Esegui test
aws stepfunctions start-execution \
  --endpoint-url http://localhost:4566 \
  --region eu-west-1 \
  --state-machine-arn arn:aws:states:eu-west-1:000000000000:stateMachine:sidea-ai-clone-prod-wa-message-processor-sfn \
  --input file://test-payloads/text/01-simple-question.json
```

## Scenari di Test

### 1. Simple Question (01-simple-question.json)
- **Tipo**: Domanda semplice
- **Topic**: Finanza - ETF
- **Expected Mode**: text
- **Expected Complexity**: 0.2-0.3
- **KB Query**: Probabile (contesto insufficiente)

### 2. Complex Investment (02-complex-investment.json)
- **Tipo**: Consulenza dettagliata
- **Topic**: Finanza - Strategia investimento
- **Expected Mode**: audio
- **Expected Complexity**: 0.8-1.0
- **KB Query**: Molto probabile

### 3. Follow-up Question (03-followup-question.json)
- **Tipo**: Follow-up breve
- **Topic**: Finanza - Costi ETF
- **Expected Mode**: text
- **Expected Complexity**: 0.2-0.3
- **KB Query**: Dipende da storico sessione

### 4. Small Talk (04-small-talk.json)
- **Tipo**: Conversazione informale
- **Topic**: Small talk
- **Expected Mode**: text
- **Expected Complexity**: 0.1
- **KB Query**: No (contesto sufficiente)

### 5. Technical Comparison (05-technical-comparison.json)
- **Tipo**: Confronto tecnico
- **Topic**: Finanza - Tipologie ETF
- **Expected Mode**: text o audio
- **Expected Complexity**: 0.5-0.7
- **KB Query**: Molto probabile

## Personalizzazione

### Modifica System Prompt

Puoi personalizzare il comportamento dell'AI modificando `system_prompt`:

```json
{
  "system_prompt": "Sei un assistente esperto in [DOMINIO]. Rispondi in modo [STILE]."
}
```

### Modifica Temperature

- **0.0-0.3**: Risposte deterministiche, precise
- **0.4-0.6**: Bilanciato (consigliato)
- **0.7-1.0**: Più creativo, variabile

### Modifica Retrieval Results

- **2-3**: Query semplici, risposte brevi
- **4-5**: Standard (consigliato)
- **6-8**: Query complesse, risposte dettagliate

## Costi Stimati

Ogni test con Bedrock reale costa circa:

- **Claude 3 Haiku** (topic-analyzer, context-evaluator): ~$0.0001 per invocazione
- **Claude 3.5 Sonnet** (reply-strategy): ~$0.001 per invocazione
- **Claude 3 Sonnet** (generate-response): ~$0.003-0.015 per invocazione
- **Knowledge Base Query**: ~$0.0001 per query

**Totale per test**: ~$0.01-0.05

## Note Importanti

⚠️ **Bedrock Reale**: Questi test chiamano AWS Bedrock reale e consumano quota.

⚠️ **Knowledge Base**: Assicurati che il KB ID `PDZQMPE5HM` esista e contenga documenti.

⚠️ **Credenziali**: Le credenziali AWS devono essere configurate nel file `.env`.

⚠️ **Rate Limiting**: Attendi 3-5 secondi tra test consecutivi per evitare throttling.

## Troubleshooting

### Errore: Knowledge Base not found

```bash
# Verifica che il KB esista
aws bedrock-agent get-knowledge-base \
  --knowledge-base-id PDZQMPE5HM \
  --region eu-west-1
```

### Errore: Throttling

Riduci la frequenza dei test o aumenta il delay tra esecuzioni.

### Errore: Invalid credentials

Verifica che le credenziali nel `.env` siano corrette e abbiano i permessi necessari:
- `bedrock:InvokeModel`
- `bedrock-agent:Retrieve`
