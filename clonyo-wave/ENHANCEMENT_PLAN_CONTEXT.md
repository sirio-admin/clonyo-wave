# Piano di Implementazione: Arricchimento Contesto Avanzato (v3 - Sequential)

Questo documento descrive l'architettura aggiornata per includere **Topic Modeling Sequenziale** e **Controllo Sufficienza Contesto**.

## 1. Modifiche alla Struttura della Step Function

Il flusso diventa sequenziale per sfruttare l'output di ogni step come input per il successivo.

### Sequenza Logica Proposta
`ManageSession` -> `AnalyzeTopic` -> `GetTopicContext` -> `CheckSufficiency` -> (Branch) -> `Strategy`

### A. Nuovo Step Sequenziale: `AnalyzeTopic`
Eseguito dopo il salvataggio del messaggio.
*   **Input**: Messaggio Utente.
*   **Azione**: Determina il topic corrente.
*   **Output**: `topic_id`, `keywords`.

### B. Nuovo Step Sequenziale: `GetTopicContext`
Eseguito subito dopo l'analisi del topic.
*   **Input**: `topic_id` (dallo step precedente).
*   **Azione**: Query su DynamoDB per recuperare riassunti di sessioni passate *filtrati per questo topic*.
*   **Output**: `historical_context` (array di sommari).

### C. Nuovo Blocco Logico: `CheckSufficiency`
Un blocco "Choice" o una Lambda veloce che valuta se abbiamo abbastanza info.

1.  **Lambda Check**: `EvaluateContextSufficiency`
    *   **Prompt**: "Data la domanda dell'utente X e il contesto storico Y recuperato, hai informazioni sufficienti per rispondere? Rispondi YES/NO."
    *   **Costo**: Molto basso (modello Haiku/Instant).

2.  **Choice State**:
    *   If `YES`: Vai direttamente a `Get Reply Strategy`.
    *   If `NO`: Vai a `QueryStaticKB`.

### D. Step Opzionale: `QueryStaticKB`
Eseguito solo se il contesto storico non basta.
*   **Azione**: Chiama Bedrock Knowledge Base (RAG su documenti S3).
*   **Output**: `kb_documents`.

---

## 2. Nuove Risorse & Modifiche

### A. Lambda Aggiornate
*   **`topic-analyzer-fn`**: Restituisce topic esplicito.
*   **`context-evaluator-fn`** (Nuova): Implementa la logica del Check Sufficiency.

### B. DynamoDB Access Patterns
*   **Query su `TopicIndex`**: Essenziale per `GetTopicContext`.

---

## 3. Flusso Dati (Payload)

Il payload si arricchisce passo dopo passo:

1.  Start: `{ "userInput": "..." }`
2.  After ManageSession: `{ ..., "session": { "id": "123", "active": true } }`
3.  After AnalyzeTopic: `{ ..., "topic": { "id": "investments", "confidence": 0.9 } }`
4.  After GetContext: `{ ..., "memory": ["Session 1: User asked about ETF..."] }`
5.  After CheckSufficiency: `{ ..., "needs_kb": true/false }`
6.  (Optional) After QueryKB: `{ ..., "kb_docs": ["Doc 1 text..."] }`

---

## 4. Analisi Performance e Latenza (Stimata)

Essendo un chatbot WhatsApp, la velocità è critica. Ecco una stima dei tempi per il flusso sequenziale completo.

### Assunzioni
*   **Cold Start**: Non inclusi (si assume Lambda calda o Provisioned Concurrency). Mantenere le Lambda calde è vitale.
*   **Modelli**: 
    *   `AnalyzeTopic` & `CheckSufficiency`: **Claude 3 Haiku** (Consigliato per velocità).
    *   `GenerateResponse`: **Claude 3.5 Sonnet** (Attuale, alta qualità).

### Breakdown Tempi di Esecuzione

| Step | Azione | Modello Consigliato | Tempo Stimato (Warm) | Note |
| :--- | :--- | :--- | :--- | :--- |
| **1. Manage Session** | DB query (veloce) | - | ~50-100ms | Trascurabile |
| **2. Analyze Topic** | Classificazione | **Haiku** | ~400-600ms | Sonnet impiegherebbe ~1-2s. Usare Haiku. |
| **3. Get Context** | DB query (veloce) | - | ~50-100ms | Trascurabile |
| **4. Check Sufficiency** | Yes/No check | **Haiku** | ~400-600ms | Prompt molto corto ("Yes/No") |
| **5. (Branch A) Sufficient** | Nessuna azione | - | 0ms | **SCENARIO VELOCE** |
| **5. (Branch B) Query KB** | RAG (Embed+Search) | - | ~800-1500ms | Dipende dalla dimensione dei docs |
| **6. Strategy** | Decisione Audio/Text | **Haiku** (Opt) | ~500ms | Attualmente usa Sonnet (~2s). **Da ottimizzare.** |
| **7. Generate Response** | Generazione Testo | **Sonnet** | ~3000-6000ms | Dipende dalla lunghezza output |
| **8. Overhead AWS** | Step Function Transitions | - | ~200ms | Totale transizioni |

### Scenari Totali

#### Scenario A: Memoria Sufficiente (Fast Path)
*   **Totale Stimato**: 4.5s - 8s
*   **Percezione Utente**: Ottima per un'AI complessa.

#### Scenario B: Serve KB (RAG Path)
*   **Totale Stimato**: 5.5s - 10s
*   **Percezione Utente**: Accettabile, ma al limite.

### Raccomandazioni per Evitare Colli di Bottiglia
1.  **USARE HAIKU**: Per `AnalyzeTopic`, `CheckSufficiency` e anche `GetReplyStrategy`, **devi** usare Claude 3 Haiku. È 3x-5x più veloce di Sonnet e costa molto meno, pur essendo sufficientemente intelligente per questi task di classificazione.
2.  **Streaming (Opzionale)**: Se la Step Function lo rendesse difficile, considera che WhatsApp non supporta lo streaming del testo (token by token), quindi l'utente aspetta comunque la fine.
3.  **Ottimizzare `GetReplyStrategy`**: Ho notato nel codice che usa Sonnet. Passalo a Haiku per risparmiare 1-1.5 secondi preziosi.

---

## 5. Strategia di Test Sicura (LocalStack Sandbox)

Per **NON toccare nulla** su AWS Prod durante lo sviluppo, useremo LocalStack per creare un ambiente parallelo effimero.

### Il Concetto di "Sandbox Locale"
Creeremo un ambiente che replica l'infrastruttura (Step Functions, DynamoDB) interamente sul tuo PC.
*   **Step Function Locale**: Creeremo una nuova Step Function `sidea-wa-processor-v3-dev` su LocalStack.
*   **Database Locali**: Tabelle `sessions` e `messages` create solo in locale.
*   **Lambda Locali**: Eseguite via Docker, collegate a LocalStack.

### Cosa resta su Cloud (Solo Stateless)
L'unica cosa che le Lambda locali faranno verso il vero AWS sarà chiamare **Bedrock**.
*   Configureremo le Lambda locali con le credenziali AWS (Read-Only per Bedrock).
*   Questo è **sicuro al 100%**: invocare un modello è un'azione stateless, non modifica nessun dato o configurazione sul tuo account reale.

### Setup Necessario
1.  **Docker Compose**: Creeremo un file per alzare LocalStack e le Lambda.
2.  **Init Script**: Uno script che, all'avvio, crea la Step Function v3 e le Tabelle su LocalStack.
3.  **Testing**: Eseguirai `aws stepfunctions start-execution --endpoint-url http://localhost:4566` per testare il nuovo flusso.

In questo modo, potrai validare l'intera nuova architettura (sessioni, topic, flussi paralleli) senza aver fatto nemmeno un deploy o una modifica all'infrastruttura esistente.
