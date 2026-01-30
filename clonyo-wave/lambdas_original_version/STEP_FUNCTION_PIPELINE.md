# Step Function Pipeline: WhatsApp Message Processor

Documentazione dettagliata della pipeline AWS Step Function per il processamento dei messaggi WhatsApp con AI e voice cloning.

**Step Function Name**: `sidea-ai-clone-prod-wa-message-processor-sfn`
**ARN**: `arn:aws:states:eu-west-1:533267110337:stateMachine:sidea-ai-clone-prod-wa-message-processor-sfn`
**Type**: STANDARD
**Query Language**: JSONata

---

## Panoramica

Questa Step Function orchestra il flusso completo di elaborazione dei messaggi WhatsApp:
1. Riceve messaggi (testo o audio) da WhatsApp
2. Trascrive i messaggi audio (se necessario)
3. Determina la strategia di risposta ottimale (testo vs audio)
4. Genera una risposta AI usando Bedrock con Knowledge Base
5. Converte la risposta in audio (se richiesto) usando voice cloning
6. Invia la risposta all'utente su WhatsApp
7. Mantiene lo storico completo della conversazione in DynamoDB

---

## Diagramma di Flusso

```
START
  ↓
[1] ExtractVariables (Pass)
  ↓
[2] Store WA message meta (DynamoDB)
  ↓
[3] Evaluate message type (Choice)
  ├─→ TEXT ─────────────────────────┐
  │                                  ↓
  └─→ AUDIO                    [9] TransformForResponse
       ↓                             ↓
      [4a] StartTranscriptionJob    [10] Store WA received message
       ↓                             ↓
      [5a] Wait 5s                  [11] Get reply strategy (Lambda)
       ↓                             ↓
      [6a] GetTranscriptionJob      [12] Build Knowledge based response (Lambda)
       ↓                             ↓
      [7a] Job finished? (Choice)   [13] Choose output type (Choice)
       ├─→ FAILED → Fail              ├─→ TEXT ──────────┐
       ├─→ IN_PROGRESS → loop to 5a   │                   ↓
       └─→ COMPLETED                  │            [14b] Reply with text
            ↓                         │                   ↓
           [8a] Get transcript file   └─→ AUDIO          [17] Store WA sent message
            ↓                              ↓               ↓
           ──────────────────────────→ [9] Transform     [18] Success (END)
                                           ↓
                                      [14a] Generate audio from text (Lambda)
                                           ↓
                                      [15a] PostWhatsAppMessageMedia
                                           ↓
                                      [16a] Reply with media
                                           ↓
                                      [17] Store WA sent message
                                           ↓
                                      [18] Success (END)
```

---

## Descrizione Dettagliata degli Stati

### FASE 1: Inizializzazione

#### [1] ExtractVariables
- **Type**: Pass State
- **Purpose**: Estrae e normalizza le variabili chiave dall'input della Step Function

**Input Example**:
```json
{
  "wa_contact": {
    "wa_id": "393462454282",
    "profile": {
      "name": "Mario Rossi"
    }
  },
  "message_ts": 1738162800,
  "reply_to_wa_id": "393462454282",
  "config": {
    "wa_phone_number_arn": "arn:aws:...",
    "response_generator": { ... },
    "text_to_speech": { ... }
  },
  "text": {
    "body": "Ciao, come stai?"
  }
}
```

**Variables Extracted** (usando JSONata):
```jsonata
{
  "wa_contact_id": $states.input.wa_contact.wa_id,
  "message_ts": $states.input.message_ts,
  "reply_to_wa_id": $states.input.reply_to_wa_id,
  "wa_phone_number_arn": $states.input.config.wa_phone_number_arn,
  "config": $states.input.config
}
```

---

#### [2] Store WA message meta
- **Type**: Task (DynamoDB PutItem)
- **Purpose**: Aggiorna i metadati del contatto con l'ultimo timestamp di interazione

**DynamoDB Operation**:
```json
{
  "TableName": "sidea-ai-clone-prod-messages-table",
  "Item": {
    "pk": { "S": "S#{wa_phone_number_arn}#C#{wa_contact_id}" },
    "sk": { "S": "META" },
    "wa_phone_number_arn": { "S": "arn:aws:..." },
    "wa_contact_id": { "S": "393462454282" },
    "wa_contact_profile_name": { "S": "Mario Rossi" },
    "last_message_at_ts": { "N": "1738162800" }
  }
}
```

**Perché è importante**:
- Permette di ordinare i contatti per ultimo messaggio
- Mantiene il nome del profilo aggiornato
- Utile per analytics e reporting

---

### FASE 2: Routing per Tipo di Messaggio

#### [3] Evaluate message type
- **Type**: Choice State
- **Purpose**: Determina se il messaggio è testo o audio

**Decision Logic**:
```jsonata
# Se esiste il campo text → messaggio testuale
$exists($states.input.text) → TransformForResponse

# Se esiste il campo audio → messaggio vocale
$exists($states.input.audio) → StartTranscriptionJob

# Default → Fail
```

**Branch A**: Messaggio di testo → salta direttamente a [9] TransformForResponse
**Branch B**: Messaggio audio → continua con trascrizione

---

### FASE 2A: Trascrizione Audio (Branch Audio)

#### [4a] StartTranscriptionJob
- **Type**: Task (AWS Transcribe SDK)
- **Purpose**: Avvia un job di trascrizione audio su Amazon Transcribe

**Input del Messaggio Audio**:
```json
{
  "audio": {
    "s3_uri": "s3://bucket-name/audio/message-123.ogg",
    "mime_type": "audio/ogg; codecs=opus"
  }
}
```

**Transcribe Job Parameters**:
```json
{
  "Media": {
    "MediaFileUri": "s3://bucket-name/audio/message-123.ogg"
  },
  "LanguageCode": "it-IT",
  "TranscriptionJobName": "ai-clone-demo_550e8400-e29b-41d4-a716-446655440000"
}
```

**Output Variable**:
```jsonata
transcriptionJobName = $states.result.TranscriptionJob.TranscriptionJobName
```

---

#### [5a] Wait for job to complete
- **Type**: Wait State
- **Purpose**: Aspetta 5 secondi prima di controllare lo stato del job
- **Duration**: 5 seconds

**Nota**: Amazon Transcribe richiede tempo per processare l'audio. Il polling pattern permette di controllare periodicamente lo stato senza occupare risorse.

---

#### [6a] GetTranscriptionJob
- **Type**: Task (AWS Transcribe SDK)
- **Purpose**: Recupera lo stato corrente del job di trascrizione

**Request**:
```json
{
  "TranscriptionJobName": "ai-clone-demo_550e8400-e29b-41d4-a716-446655440000"
}
```

**Response**:
```json
{
  "TranscriptionJob": {
    "TranscriptionJobName": "ai-clone-demo_...",
    "TranscriptionJobStatus": "COMPLETED|IN_PROGRESS|FAILED",
    "Transcript": {
      "TranscriptFileUri": "https://s3.amazonaws.com/..."
    }
  }
}
```

---

#### [7a] Job finished?
- **Type**: Choice State
- **Purpose**: Verifica lo stato del job e decide il prossimo passo

**Decision Logic**:
```jsonata
# Job completato → procedi al download del transcript
$states.input.TranscriptionJob.TranscriptionJobStatus = "COMPLETED"
  → Get transcript file content

# Job fallito → termina con errore
$states.input.TranscriptionJob.TranscriptionJobStatus = "FAILED"
  → Fail

# Job ancora in corso (IN_PROGRESS) → aspetta ancora
Default → Wait for job to complete (loop back to [5a])
```

**Polling Pattern**: Questo crea un loop che continua finché il job non è completato o fallito.

---

#### [8a] Get transcript file content
- **Type**: Task (Lambda Invoke)
- **Lambda**: `sidea-ai-clone-prod-get-file-contents-fn`
- **Purpose**: Scarica e legge il file JSON del transcript da S3

**Lambda Input**:
```json
{
  "file_uri": "https://s3.amazonaws.com/aws-transcribe-eu-west-1-prod/..."
}
```

**Lambda Handler**: `App\Handlers\GetFileContentsHandler`

**Lambda Logic**:
1. Fa una HTTP GET request all'URI del transcript
2. Legge il file JSON
3. Restituisce il contenuto completo

**Transcript File Structure**:
```json
{
  "jobName": "ai-clone-demo_...",
  "accountId": "533267110337",
  "results": {
    "transcripts": [
      {
        "transcript": "Ciao, vorrei sapere come investire in ETF"
      }
    ],
    "items": [ ... ]
  },
  "status": "COMPLETED"
}
```

**Output Transformation** (JSONata):
```jsonata
transcript = $parse($states.result.Payload.content).results.transcripts[0].transcript
```

**Result**:
```json
{
  "transcript": "Ciao, vorrei sapere come investire in ETF"
}
```

**Retry Policy**:
- Max Attempts: 3
- Interval: 1 second
- Backoff Rate: 2x (1s, 2s, 4s)
- Jitter: FULL

---

### FASE 3: Convergenza e Normalizzazione

#### [9] TransformForResponse
- **Type**: Pass State
- **Purpose**: Normalizza l'input da entrambi i percorsi (testo/audio) in un formato uniforme

**Input Scenarios**:

**Scenario 1 - Testo Diretto**:
```json
{
  "text": {
    "body": "Ciao, come stai?"
  }
}
```

**Scenario 2 - Audio Trascritto**:
```json
{
  "transcript": "Ciao, come stai?"
}
```

**Output Normalization** (JSONata):
```jsonata
{
  "userInput": $exists($states.input.transcript)
    ? $states.input.transcript
    : $states.input.text.body,

  "original_input_type": $exists($states.input.transcript)
    ? "audio"
    : "text",

  "config": $config.response_generator,

  "messages_key": "S#" & $wa_phone_number_arn & "#C#" & $wa_contact_id
}
```

**Output Unificato**:
```json
{
  "userInput": "Ciao, come stai?",
  "original_input_type": "text",
  "config": {
    "provider": "bedrock",
    "knowledge_base_id": "KB123...",
    "system_prompt": "...",
    "retrieval_results": 4,
    "temperature": 0.5,
    "max_tokens": 4096
  },
  "messages_key": "S#arn:aws:...#C#393462454282"
}
```

---

#### [10] Store WA received message
- **Type**: Task (DynamoDB PutItem)
- **Purpose**: Salva il messaggio dell'utente nello storico della conversazione

**DynamoDB Operation**:
```json
{
  "TableName": "sidea-ai-clone-prod-messages-table",
  "Item": {
    "pk": { "S": "S#arn:aws:...#C#393462454282" },
    "sk": { "S": "M#1738162800" },
    "role": { "S": "user" },
    "type": { "S": "text" },
    "content": { "S": "Ciao, come stai?" }
  }
}
```

**DynamoDB Schema**:
- **pk** (Partition Key): `S#{wa_phone_number_arn}#C#{contact_id}` - Raggruppa tutti i messaggi di una conversazione
- **sk** (Sort Key): `M#{timestamp}` - Ordina i messaggi cronologicamente
- **role**: `"user"` o `"assistant"`
- **type**: `"text"` o `"audio"`
- **content**: Il testo del messaggio

**Query Pattern**: Questa struttura permette di recuperare facilmente:
- Tutti i messaggi di un contatto specifico
- I messaggi ordinati cronologicamente
- Solo i metadati del contatto (sk = "META")

---

### FASE 4: Generazione Risposta AI

#### [11] Get reply strategy
- **Type**: Task (Lambda Invoke)
- **Lambda**: `sidea-ai-clone-prod-reply-strategy-fn`
- **Purpose**: Analizza il messaggio dell'utente e lo storico per determinare la migliore strategia di risposta

**Lambda Handler**: `App\Handlers\ReplyStrategyHandler`

**Service**: `App\Services\ReplyStrategyService`

**Lambda Input**:
```json
{
  "userInput": "Vorrei sapere come gestire i miei investimenti in ETF",
  "messages_key": "S#arn:aws:...#C#393462454282",
  "config": { ... }
}
```

**Lambda Logic**:

1. **Recupera Storico Conversazione**:
   ```php
   $messages = $this->messages->all($messages_key);
   // Prende gli ultimi 10 messaggi
   $this->messages = collect($messages)->take(-10);
   ```

2. **Costruisce Prompt per Claude 3.5 Sonnet**:
   - System Prompt dettagliato con euristiche per classificazione
   - Conversation history (ultimi 10 messaggi)
   - Messaggio corrente dell'utente

3. **Chiama Bedrock con Claude 3.5 Sonnet**:
   ```php
   $bedrock_client->invokeModel([
       'modelId' => 'eu.anthropic.claude-3-5-sonnet-20240620-v1:0',
       'body' => json_encode([
           'anthropic_version' => 'bedrock-2023-05-31',
           'temperature' => 0,
           'max_tokens' => 100,
           'system' => $systemPrompt,
           'messages' => $conversationHistory
       ])
   ]);
   ```

4. **Analizza Risposta**:
   - Tema conversazione (SMALL_TALK, INFO_LOOKUP, FINANZA, CONSIGLIO_PERSONALE, ecc.)
   - Tipo di domanda (FACT_LOOKUP, CONFRONTO, HOWTO, STRATEGIA, CONSIGLIO_EMOTIVO)
   - Contesto emotivo e profondità richiesta

**Euristiche Principali**:
- **Small talk** → mode="text", complexity=0.1
- **Info lookup** (link, titoli) → mode="text", complexity=0.2-0.3
- **Finanza/Tecnologia**:
  - Domanda tecnica → mode="audio", complexity=0.8-1.0
  - Consiglio pratico → mode="audio", complexity=0.6-0.8
  - Confronto semplice → mode="text", complexity=0.3-0.5
- **Consiglio personale/emotivo** → mode="audio", complexity=0.8-1.0
- **Follow-up brevi** ("Ok", "Grazie") → mode="text", complexity=0.1-0.2

**Lambda Output**:
```json
{
  "mode": "audio",
  "complexity_factor": 0.8
}
```

**Retry Policy**:
- Max Attempts: 11
- Interval: 5 seconds
- Backoff Rate: 1.09
- Total Duration: ~88 seconds
- Comment: "Waits: 5.0s, 5.45s, 5.94s, 6.48s, 7.06s, 7.69s, 8.39s, 9.14s, 9.96s, 10.86s, 11.84s"

**Variables Assigned**:
```jsonata
output_message_type = $states.result.Payload.mode
complexity_factor = $states.result.Payload.complexity_factor
```

---

#### [12] Build Knowledge based response
- **Type**: Task (Lambda Invoke)
- **Lambda**: `sidea-ai-clone-prod-generate-response-fn`
- **Purpose**: Genera la risposta AI usando AWS Bedrock con Knowledge Base

**Lambda Handler**: `App\Handlers\GenerateResponseHandler`

**Service**: `App\Services\ResponseGenerator\BedrockService`

**Lambda Input** (merge con complexity_factor):
```json
{
  "userInput": "Vorrei sapere come gestire i miei investimenti in ETF",
  "messages_key": "S#arn:aws:...#C#393462454282",
  "config": {
    "provider": "bedrock",
    "knowledge_base_id": "KB123ABC...",
    "system_prompt": "Sei un assistente esperto in finanza...",
    "retrieval_results": 4,
    "temperature": 0.5,
    "max_tokens": 4096
  },
  "complexity_factor": 0.8,
  "with_context": true
}
```

**Lambda Logic**:

1. **Recupera Storico Conversazione**:
   ```php
   $messages = $this->messages->all($messages_key);
   ```

2. **Retrieve from Knowledge Base**:
   - Query alla Knowledge Base di Bedrock
   - Recupera `retrieval_results` documenti rilevanti (default: 4)
   - I documenti forniscono contesto specifico del dominio

3. **Costruisce Prompt con RAG** (Retrieval Augmented Generation):
   ```
   System: [system_prompt]

   Context from Knowledge Base:
   [documento 1]
   [documento 2]
   [documento 3]
   [documento 4]

   Conversation History:
   User: [messaggio 1]
   Assistant: [risposta 1]
   ...

   User: [messaggio corrente]
   ```

4. **Chiama Claude 3 Sonnet via Bedrock**:
   ```php
   $bedrock_client->invokeModel([
       'modelId' => 'anthropic.claude-3-sonnet-20240229-v1:0',
       'body' => json_encode([
           'temperature' => 0.5,
           'max_tokens' => 4096,  // Modificato da complexity_factor
           'system' => $systemPrompt,
           'messages' => $conversationWithContext
       ])
   ]);
   ```

5. **Adatta risposta al complexity_factor**:
   - complexity_factor alto (0.8-1.0) → risposta più dettagliata, esempi, spiegazioni
   - complexity_factor basso (0.1-0.3) → risposta concisa, diretta

**Lambda Output**:
```json
{
  "response": "Gli ETF (Exchange Traded Funds) sono fondi indicizzati che replicano l'andamento di un indice di mercato. Per investire in ETF, ti consiglio di: 1) Aprire un conto titoli presso una banca o broker online, 2) Identificare gli ETF più adatti al tuo profilo di rischio, 3) Considerare ETF ad accumulazione per beneficiare dell'interesse composto, 4) Diversificare tra asset class diverse..."
}
```

**Retry Policy**:
- Max Attempts: 11
- Interval: 5 seconds
- Backoff Rate: 1.09
- Total Duration: ~88 seconds

**Variable Assigned**:
```jsonata
output_message_content = $states.result.Payload.response
```

**Output State** (sostituisce tutto lo stato):
```jsonata
Output = $states.result.Payload
```

---

### FASE 5: Delivery della Risposta

#### [13] Choose output type
- **Type**: Choice State
- **Purpose**: Determina se inviare la risposta come testo o audio

**Decision Logic**:
```jsonata
# Se mode = "audio" → genera audio
$output_message_type = "audio" → Generate audio from text

# Se mode = "text" → invia testo diretto
$output_message_type = "text" → Reply to WA User with text

# Default (fallback sicuro) → salta a Store WA sent message
Default → Store WA sent message
```

**Default Assign** (se nessuna condizione match):
```jsonata
output_message_type = "text"
```

---

### FASE 5A: Percorso Audio

#### [14a] Generate audio from text
- **Type**: Task (Lambda Invoke)
- **Lambda**: `sidea-ai-clone-prod-text-to-speech-fn`
- **Purpose**: Converte il testo della risposta in audio usando ElevenLabs voice cloning

**Lambda Handler**: `App\Handlers\TextToSpeechHandler`

**Service**: `App\Services\TextToSpeechConverter\ElevenlabsService`

**Lambda Input**:
```json
{
  "text": "Gli ETF sono fondi indicizzati che replicano...",
  "config": {
    "provider": "elevenlabs",
    "api_key": "sk_...",
    "voice_id": "pNInz6obpgDQGcFmaJgB",
    "output_format": "opus_48000_32",
    "stability": 0.76,
    "similarity_boost": 0.88,
    "style": 0.10,
    "use_speaker_boost": null,
    "speed": null,
    "request_timeout": 58
  },
  "wa_phone_number_arn": "arn:aws:..."
}
```

**Lambda Logic**:

1. **Chiama ElevenLabs API**:
   ```php
   POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}
   Headers:
     xi-api-key: {api_key}
   Body:
   {
     "text": "Gli ETF sono fondi...",
     "model_id": "eleven_multilingual_v2",
     "voice_settings": {
       "stability": 0.76,
       "similarity_boost": 0.88,
       "style": 0.10,
       "use_speaker_boost": false
     },
     "output_format": "opus_48000_32"
   }
   ```

2. **Riceve Audio Stream**:
   - Formato: Opus codec a 48kHz, 32kbps
   - Ottimizzato per WhatsApp

3. **Genera Path S3**:
   ```php
   $path = "{wa_phone_number_arn}/outgoing/{uuid}.ogg";
   // Esempio: "arn-aws-.../outgoing/550e8400-e29b-41d4-a716-446655440000.ogg"
   ```

4. **Upload su S3**:
   ```php
   Storage::disk('s3')->put($path, $audioStream);
   ```

**Lambda Output**:
```json
{
  "bucket_name": "sidea-ai-clone-prod-wa-media-s3",
  "key": "arn-aws-.../outgoing/550e8400-e29b-41d4-a716-446655440000.ogg"
}
```

**Retry Policy**:
- Max Attempts: 3
- Interval: 3 seconds
- Backoff Rate: 2x (3s, 6s, 12s)
- Jitter: FULL
- Errors: Lambda service exceptions only

**Note**:
- Timeout Lambda: 60 secondi
- Timeout ElevenLabs request: 58 secondi (per avere 2s di buffer)
- Voice cloning mantiene caratteristiche vocali uniche

---

#### [15a] PostWhatsAppMessageMedia
- **Type**: Task (AWS Social Messaging SDK)
- **Purpose**: Carica il file audio su WhatsApp Business Platform e ottiene un media ID

**AWS Service**: `socialmessaging:postWhatsAppMessageMedia`

**Request**:
```json
{
  "OriginationPhoneNumberId": "arn:aws:...",
  "SourceS3File": {
    "BucketName": "sidea-ai-clone-prod-wa-media-s3",
    "Key": "arn-aws-.../outgoing/550e8400-e29b-41d4-a716-446655440000.ogg"
  }
}
```

**What Happens**:
1. AWS Social Messaging scarica il file da S3
2. Carica il file su WhatsApp Business API
3. WhatsApp genera un media ID univoco
4. Il media ID è valido per invio per un periodo limitato

**Response**:
```json
{
  "MediaId": "wamid.HBgNMzkzNDYyNDU0MjgyFQIAERgSN0Q0QjU5..."
}
```

**Note**: Il MediaId è temporaneo e deve essere usato subito per l'invio.

---

#### [16a] Reply to WA User with media
- **Type**: Task (AWS Social Messaging SDK)
- **Purpose**: Invia il messaggio audio all'utente su WhatsApp

**AWS Service**: `socialmessaging:sendWhatsAppMessage`

**Request**:
```json
{
  "Message": {
    "messaging_product": "whatsapp",
    "to": "393462454282",
    "type": "audio",
    "audio": {
      "id": "wamid.HBgNMzkzNDYyNDU0MjgyFQIAERgSN0Q0QjU5..."
    }
  },
  "MetaApiVersion": "v21.0",
  "OriginationPhoneNumberId": "arn:aws:..."
}
```

**What Happens**:
1. AWS Social Messaging chiama Meta WhatsApp API v21.0
2. WhatsApp invia il messaggio audio al numero destinatario
3. L'utente riceve il messaggio vocale nella chat

**Response**:
```json
{
  "MessageId": "wamid.HBgNMzk...",
  "Status": "sent"
}
```

---

### FASE 5B: Percorso Testo

#### [14b] Reply to WA User with text
- **Type**: Task (AWS Social Messaging SDK)
- **Purpose**: Invia il messaggio di testo all'utente su WhatsApp

**AWS Service**: `socialmessaging:sendWhatsAppMessage`

**Request**:
```json
{
  "Message": {
    "messaging_product": "whatsapp",
    "to": "393462454282",
    "type": "text",
    "text": {
      "body": "Gli ETF sono fondi indicizzati che replicano l'andamento di un indice di mercato. Per investire in ETF, ti consiglio di..."
    }
  },
  "MetaApiVersion": "v21.0",
  "OriginationPhoneNumberId": "arn:aws:..."
}
```

**What Happens**:
1. AWS Social Messaging chiama Meta WhatsApp API v21.0
2. WhatsApp invia il messaggio di testo al numero destinatario
3. L'utente riceve il messaggio nella chat

**Response**:
```json
{
  "MessageId": "wamid.HBgNMzk...",
  "Status": "sent"
}
```

**Note**: I messaggi di testo hanno limite di 4096 caratteri su WhatsApp.

---

### FASE 6: Finalizzazione

#### [17] Store WA sent message
- **Type**: Task (DynamoDB PutItem)
- **Purpose**: Salva la risposta dell'assistente nello storico della conversazione

**DynamoDB Operation**:
```json
{
  "TableName": "sidea-ai-clone-prod-messages-table",
  "Item": {
    "pk": { "S": "S#arn:aws:...#C#393462454282" },
    "sk": { "S": "M#1738162850" },
    "role": { "S": "assistant" },
    "type": { "S": "audio" },
    "content": { "S": "Gli ETF sono fondi indicizzati che replicano..." }
  }
}
```

**Timestamp Generation** (JSONata):
```jsonata
sk = "M#" & $string($round($millis() / 1000))
```
Usa il timestamp corrente in millisecondi, diviso per 1000 per ottenere secondi Unix.

**Note Importanti**:
- Il `content` contiene sempre il TESTO della risposta, anche se inviata come audio
- Questo permette di fare ricerche full-text e mantenere lo storico testuale
- Il campo `type` indica se la risposta è stata effettivamente inviata come "text" o "audio"

**Storico Completo**:
Ora in DynamoDB abbiamo:
```
pk: S#arn:aws:...#C#393462454282
├─ sk: META → metadati contatto
├─ sk: M#1738162800 → messaggio user (input)
└─ sk: M#1738162850 → messaggio assistant (output)
```

---

#### [18] Success
- **Type**: Succeed State
- **Purpose**: Termina l'esecuzione della Step Function con successo

**Final State Output**: Mantiene l'output dello stato precedente (dati del messaggio salvato).

---

## Pattern e Strategie

### 1. Retry Strategy

La Step Function implementa retry aggressivi per garantire affidabilità:

**Lambda AI Functions** (reply-strategy, generate-response):
```json
{
  "ErrorEquals": ["States.ALL"],
  "IntervalSeconds": 5,
  "MaxAttempts": 11,
  "BackoffRate": 1.09,
  "MaxDelaySeconds": 1
}
```
- **Totale**: ~88 secondi di retry
- **Progressione**: 5.0s → 5.45s → 5.94s → 6.48s → 7.06s → 7.69s → 8.39s → 9.14s → 9.96s → 10.86s → 11.84s
- **Rationale**: Le chiamate a Bedrock possono subire throttling temporaneo

**Text-to-Speech Lambda**:
```json
{
  "ErrorEquals": [
    "Lambda.ServiceException",
    "Lambda.AWSLambdaException",
    "Lambda.SdkClientException",
    "Lambda.TooManyRequestsException"
  ],
  "IntervalSeconds": 3,
  "MaxAttempts": 3,
  "BackoffRate": 2,
  "JitterStrategy": "FULL"
}
```
- **Totale**: 3 tentativi (3s → 6s → 12s)
- **Jitter**: FULL per evitare thundering herd

**Get File Contents Lambda**:
```json
{
  "ErrorEquals": [
    "Lambda.ServiceException",
    "Lambda.AWSLambdaException",
    "Lambda.SdkClientException",
    "Lambda.TooManyRequestsException"
  ],
  "IntervalSeconds": 1,
  "MaxAttempts": 3,
  "BackoffRate": 2,
  "JitterStrategy": "FULL"
}
```
- **Totale**: 3 tentativi rapidi (1s → 2s → 4s)

### 2. Polling Pattern (Transcription)

Per Amazon Transcribe viene usato un pattern di polling con wait:

```
StartTranscriptionJob
  ↓
Wait 5 seconds
  ↓
GetTranscriptionJob
  ↓
Check Status
  ├─ COMPLETED → Continue
  ├─ FAILED → Fail
  └─ IN_PROGRESS → Wait 5 seconds (loop)
```

**Perché 5 secondi?**
- Bilancia tra latenza e costi
- I messaggi vocali WhatsApp sono tipicamente brevi (< 30 secondi)
- Transcribe impiega circa 10-30 secondi per audio brevi

**Alternative considerate**:
- Wait dinamico basato su durata audio: più complesso
- Callback da Transcribe: richiede EventBridge e maggiore complessità

### 3. Data Transformation con JSONata

La Step Function usa JSONata per trasformazioni dati complesse:

**Example 1 - Estrazione Condizionale**:
```jsonata
userInput = $exists($states.input.transcript)
  ? $states.input.transcript
  : $states.input.text.body
```

**Example 2 - String Concatenation**:
```jsonata
pk = "S#" & $wa_phone_number_arn & "#C#" & $wa_contact_id
```

**Example 3 - Nested JSON Parsing**:
```jsonata
transcript = $parse($states.result.Payload.content).results.transcripts[0].transcript
```

**Example 4 - Object Merge**:
```jsonata
Payload = $merge([$states.input, {"complexity_factor": $complexity_factor}])
```

### 4. Variable Scoping

Le variabili vengono gestite a livello di Step Function:

**Variables Create (Assign)**:
```jsonata
Assign: {
  "wa_contact_id": "{% $states.input.wa_contact.wa_id %}",
  "output_message_type": "{% $states.result.Payload.mode %}"
}
```

**Variables Access**:
- `$wa_contact_id` - accessibile in tutti gli stati successivi
- `$config` - accessibile globalmente
- `$states.input` - input dello stato corrente
- `$states.result` - output dell'ultima task

**Variable Lifecycle**:
- Create in `ExtractVariables` all'inizio
- Arricchite durante il flusso (es. `output_message_type`, `complexity_factor`)
- Usate per routing e decision logic

### 5. Error Handling

**Fail State**:
```json
"Fail": {
  "Type": "Fail"
}
```

**Used When**:
- Tipo di messaggio non riconosciuto (né text né audio)
- Transcription job fallito
- Errori non recuperabili

**Dead Letter Queue**: Le esecuzioni fallite dovrebbero essere configurate con DLQ per debugging.

---

## Metriche e Timing

### Latenze Tipiche

**Messaggio Testo → Risposta Testo**:
1. ExtractVariables: < 100ms
2. Store meta: ~50ms (DynamoDB)
3. Evaluate type: < 10ms
4. TransformForResponse: < 10ms
5. Store received: ~50ms (DynamoDB)
6. Get reply strategy: ~2-5s (Lambda + Bedrock)
7. Build response: ~5-15s (Lambda + Bedrock + Knowledge Base)
8. Reply with text: ~500ms (WhatsApp API)
9. Store sent: ~50ms (DynamoDB)

**Totale**: ~8-20 secondi

**Messaggio Audio → Risposta Audio**:
1-3. Come sopra: ~200ms
4. Start transcription: ~500ms
5-8. Polling transcription: ~10-30s (dipende da lunghezza audio)
9. Get file contents: ~1-2s
10-12. Come sopra: ~200ms
13-14. Get reply strategy: ~2-5s
15. Build response: ~5-15s
16. Generate audio: ~10-30s (dipende da lunghezza testo, ElevenLabs)
17. Post media: ~1-2s
18. Reply with media: ~500ms
19. Store sent: ~50ms

**Totale**: ~30-85 secondi

### Costi per Esecuzione

**AWS Step Functions**:
- STANDARD type: $0.025 per 1000 state transitions
- ~18 states per esecuzione: $0.00045

**Lambda Invocations**:
- reply-strategy: ~2-5s × $0.0000166667/GB-second
- generate-response: ~5-15s × $0.0000166667/GB-second
- text-to-speech (se audio): ~10-30s × $0.0000166667/GB-second
- get-file-contents (se audio): ~1s × $0.0000166667/GB-second

**DynamoDB**:
- 3-4 PutItem operations per esecuzione
- On-demand pricing: $1.25 per million writes

**Amazon Transcribe**:
- $0.024 per minuto (primi 250,000 minuti/mese)

**AWS Bedrock**:
- Claude 3.5 Sonnet: $0.003 per 1K input tokens, $0.015 per 1K output tokens
- Knowledge Base queries: $0.10 per query

**ElevenLabs** (esterno):
- Dipende dal piano, tipicamente $0.30 per 1K characters

**S3**:
- Storage: $0.023 per GB-month
- GET requests: $0.0004 per 1000
- PUT requests: $0.005 per 1000

**WhatsApp Business API**:
- Conversation-based pricing
- Business-initiated: varia per paese
- User-initiated (24h window): gratuito

---

## Monitoraggio e Debugging

### CloudWatch Logs

**Step Function Executions**:
```
Log Group: /aws/states/sidea-ai-clone-prod-wa-message-processor-sfn
```
- Event history per ogni esecuzione
- Input/output di ogni state
- Error details

**Lambda Functions**:
```
/aws/lambda/sidea-ai-clone-prod-reply-strategy-fn
/aws/lambda/sidea-ai-clone-prod-generate-response-fn
/aws/lambda/sidea-ai-clone-prod-text-to-speech-fn
/aws/lambda/sidea-ai-clone-prod-get-file-contents-fn
```

### X-Ray Tracing

Abilitato con:
```json
"tracingConfiguration": {
  "enabled": true
}
```

Visualizza:
- Latenza per ogni state
- Chiamate downstream (DynamoDB, Bedrock, ElevenLabs)
- Errori e throttling

### Metriche CloudWatch

**Step Function**:
- ExecutionsStarted
- ExecutionsSucceeded
- ExecutionsFailed
- ExecutionTime
- ExecutionThrottled

**Lambda**:
- Invocations
- Duration
- Errors
- Throttles
- ConcurrentExecutions

**DynamoDB**:
- ConsumedReadCapacityUnits
- ConsumedWriteCapacityUnits
- UserErrors
- SystemErrors

### Debugging Tips

1. **Esecuzione Fallita**:
   - Vai su Step Functions console
   - Trova execution ARN
   - Visualizza execution event history
   - Identifica lo state che ha fallito
   - Controlla input/output/error

2. **Lambda Timeout**:
   - Controlla CloudWatch Logs del Lambda
   - Cerca "Task timed out after"
   - Aumenta timeout o ottimizza codice

3. **Transcription Bloccata**:
   - Controlla se il loop di polling continua
   - Verifica permissions su S3 audio files
   - Controlla formato audio supportato

4. **Risposta Non Inviata**:
   - Verifica permissions WhatsApp Business Account
   - Controlla rate limits WhatsApp
   - Verifica formato message payload

---

## Ottimizzazioni Possibili

### 1. Parallel Processing

Attualmente sequenziale. Si potrebbe parallelizzare:

```json
"Parallel State": {
  "Type": "Parallel",
  "Branches": [
    {
      "StartAt": "Get reply strategy",
      "States": { ... }
    },
    {
      "StartAt": "Fetch user profile data",
      "States": { ... }
    }
  ]
}
```

### 2. Caching

**Reply Strategy Cache**:
- Cachare strategy per messaggi simili
- Redis/ElastiCache con TTL
- Key: hash(userInput + last_10_messages)

**Knowledge Base Cache**:
- Cachare risultati retrieval comuni
- DynamoDB TTL per invalidazione

### 3. Async Audio Generation

Per risposte audio molto lunghe:
1. Invia subito messaggio "Sto preparando la risposta audio..."
2. Genera audio in background
3. Invia audio quando pronto

### 4. Streaming Responses

Con Bedrock streaming:
1. Genera risposta in chunk
2. Invia messaggi WhatsApp multipli in tempo reale
3. Migliora perceived latency

### 5. Smart Routing

Decision tree più sofisticato:
- Lunghezza input
- Time of day
- User preferences
- Bandwidth detection

---

## Considerazioni di Sicurezza

### 1. Data Privacy

**DynamoDB Encryption**:
- Encryption at rest: AWS_OWNED_KEY
- Encryption in transit: TLS

**S3 Encryption**:
- Dovrebbe usare SSE-S3 o SSE-KMS per audio files

**WhatsApp**:
- End-to-end encrypted per i messaggi
- Metadata non encrypted

### 2. IAM Permissions

**Step Function Role**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "lambda:InvokeFunction",
        "transcribe:StartTranscriptionJob",
        "transcribe:GetTranscriptionJob",
        "socialmessaging:SendWhatsAppMessage",
        "socialmessaging:PostWhatsAppMessageMedia"
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/sidea-ai-clone-prod-messages-table",
        "arn:aws:lambda:*:*:function:sidea-ai-clone-prod-*",
        ...
      ]
    }
  ]
}
```

**Lambda Roles**:
- reply-strategy: DynamoDB read, Bedrock invoke
- generate-response: DynamoDB read, Bedrock invoke
- text-to-speech: S3 write, ElevenLabs API (via secrets)
- get-file-contents: S3 read (transcribe bucket)

### 3. Secrets Management

**ElevenLabs API Key**:
- Dovrebbe essere in AWS Secrets Manager
- Non hardcoded in config
- Rotation automatica

**Knowledge Base IDs**:
- Configuration table in DynamoDB
- Per-phone-number configuration

### 4. Rate Limiting

**Bedrock**:
- Quota limits per region
- Retry con exponential backoff

**ElevenLabs**:
- API rate limits per plan
- Queue requests se necessario

**WhatsApp**:
- 1000 messages/second per business account
- Conversation rate limits

---

## Testing

### Unit Testing

**Lambda Functions**:
```bash
cd lambdas/reply-strategy-fn
./vendor/bin/pest tests/Unit/Services/ReplyStrategyServiceTest.php
```

### Integration Testing

**Step Function Testing**:
```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:eu-west-1:533267110337:stateMachine:sidea-ai-clone-prod-wa-message-processor-sfn \
  --input file://test-events/text-message.json
```

**Test Events**:
```json
{
  "wa_contact": {
    "wa_id": "393462454282",
    "profile": {
      "name": "Test User"
    }
  },
  "message_ts": 1738162800,
  "reply_to_wa_id": "393462454282",
  "text": {
    "body": "Ciao, questo è un test"
  },
  "config": {
    "wa_phone_number_arn": "arn:aws:...",
    "response_generator": { ... },
    "text_to_speech": { ... }
  }
}
```

### Load Testing

**Concurrent Executions**:
```bash
for i in {1..100}; do
  aws stepfunctions start-execution \
    --state-machine-arn ... \
    --name "test-execution-$i" \
    --input file://test-events/text-message.json &
done
```

**Monitor**:
- Lambda concurrent executions
- DynamoDB throttling
- Bedrock throttling
- WhatsApp API rate limits

---

## Manutenzione

### Aggiornamento Lambda Functions

```bash
cd lambdas/reply-strategy-fn
composer install --no-dev
zip -r function.zip .
aws lambda update-function-code \
  --function-name sidea-ai-clone-prod-reply-strategy-fn \
  --zip-file fileb://function.zip
```

### Aggiornamento Step Function

```bash
aws stepfunctions update-state-machine \
  --state-machine-arn arn:aws:... \
  --definition file://step-function-definition.json
```

**Note**: Update NON interrompe esecuzioni in corso.

### Rollback

**Lambda**:
```bash
aws lambda publish-version \
  --function-name sidea-ai-clone-prod-reply-strategy-fn

aws lambda update-alias \
  --function-name sidea-ai-clone-prod-reply-strategy-fn \
  --name prod \
  --function-version 42
```

**Step Function**:
- Mantiene version history
- Può revert a revision precedente

---

## Conclusioni

Questa Step Function implementa una pipeline complessa ma resiliente per conversazioni AI su WhatsApp con le seguenti caratteristiche chiave:

1. **Flessibilità**: Gestisce sia input testuali che vocali
2. **Intelligenza**: Decide autonomamente la migliore modalità di risposta
3. **Scalabilità**: Serverless, scala automaticamente
4. **Affidabilità**: Retry aggressivi e error handling
5. **Context-Aware**: Mantiene storico conversazione completo
6. **Multi-modal**: Testo e audio con voice cloning
7. **RAG-Powered**: Usa Knowledge Base per risposte accurate

Il sistema è production-ready con monitoring, tracing e ottimizzazioni per costi e performance.
