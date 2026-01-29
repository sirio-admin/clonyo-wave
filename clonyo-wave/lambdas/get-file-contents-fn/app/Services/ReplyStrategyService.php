<?php

namespace App\Services;

use Aws\BedrockRuntime\BedrockRuntimeClient;
use Illuminate\Support\Collection;

class ReplyStrategyService implements \App\Contracts\ReplyStrategy
{
    protected const BEDROCK_MODEL_ID = 'eu.anthropic.claude-3-5-sonnet-20240620-v1:0';

    protected const ANTHROPIC_VERSION = 'bedrock-2023-05-31';

    protected const TEMPERATURE = 0;

    protected const MAX_TOKENS = 100;

    /**
     * @var Collection<\App\Data\ConversationMessageData>
     */
    protected Collection $messages;

    public function __construct(
        protected BedrockRuntimeClient $bedrock_client
    ) {}

    public function withMessages(Collection $messages): static
    {
        $this->messages = collect($messages)->take(-10);

        return $this;
    }

    protected function getSystemPrompt(): string
    {
        return <<<'SYSTEM'
Fai parte del sistema Clonyo.
In input ricevi un’intera conversazione in stile WhatsApp (sequenza di messaggi con {role: user|assistant, content}).
Il tuo compito è analizzare l’ultimo messaggio dell’utente tenendo conto del contesto della conversazione e restituire un JSON con due campi:

{
  "complexity_factor": <float compreso tra 0 e 1>,
  "mode": "<text|audio>"
}

Output:
- Usa valori rappresentativi (0.1, 0.3, 0.5, 0.8, 1.0) o intermedi quando necessario.
- Restituisci **solo JSON**, nessun testo aggiuntivo.

Regole principali:
1. Se l’utente chiede esplicitamente un “audio” o “voce” (in qualunque lingua) → mode="audio".
2. Se l’utente chiede esplicitamente “testo”, “messaggio” o “scrivi” (in qualunque lingua) → mode="text".
3. Altrimenti valuta in base a TEMA × TIPO_DI_DOMANDA × CONTESTO.

Temi principali (esempi, non esaustivi):
- SMALL_TALK: saluti, ringraziamenti, conferme brevi.
- INFO_LOOKUP: “dove trovo…”, “link”, titoli di libri/podcast/risorse.
- FINANZA/TECNOLOGIA: investimenti, ETF, Bitcoin, asset allocation, istruzioni tecniche.
- CONSIGLIO_PERSONALE: scelte di vita, relazioni, genitorialità.
- SALUTE/COMPORTAMENTO: abitudini, tic nervosi, benessere psicologico.
- LAVORO_VALORI: direzioni di carriera, scelte basate su valori personali.

Tipi di domanda:
- FACT_LOOKUP: recupero semplice di informazione.
- CONFRONTO_SEMPLICE: A/B breve (“ETF o azioni?”).
- HOWTO_BREVE: pochi passi, istruzioni snelle.
- HOWTO_DETTAGLIATO: procedura articolata.
- STRATEGIA_FRAMEWORK: ragionamento lungo, strutturato e personalizzato.
- CONSIGLIO_EMOTIVO: richiesta di supporto sensibile.

Contesto conversazionale:
- Considera il tono e la profondità della conversazione recente.
- Aumenta il complexity_factor quando l’utente chiede guida strutturata, personalizzazione o strategia.
- Riducilo quando chiede semplici conferme, link o informazioni brevi.

Euristiche:
- SMALL_TALK → mode="text", complexity_factor=0.1.
- INFO_LOOKUP (es. “dove trovo un libro/podcast?”) → mode="text", complexity_factor=0.2–0.3.
- FINANZA/TECNOLOGIA:
  - domanda tecnica posta in modo tecnico → mode="audio", complexity_factor=0.8–1.0.
  - richiesta di consiglio/sintesi pratica → mode="audio", complexity_factor=0.6–0.8.
  - confronto semplice (es. “ETF o azioni?” poco contestualizzato) → mode="text", complexity_factor=0.3–0.5.
- CONSIGLIO_PERSONALE o SALUTE/COMPORTAMENTO → preferisci mode="audio":
  - temi emotivi/sensibili → complexity_factor=0.8–1.0.
- LAVORO_VALORI → spesso meglio audio, complexity_factor=0.7–0.9.
- Se l’utente scrive follow-up brevi (“Ok”, “Grazie”, “Si grazie”) → mode="text", complexity_factor=0.1–0.2.
SYSTEM;
    }

    /**
     * @return array<{complexity_factor: float, mode: string}>
     */
    public function analyzeInput(string $user_input): array
    {
        $body = json_encode([
            'anthropic_version' => static::ANTHROPIC_VERSION,
            'temperature' => static::TEMPERATURE,
            'max_tokens' => static::MAX_TOKENS,
            'system' => $this->getSystemPrompt(),
            'messages' => [
                ...collect($this->messages)
                    ->map(fn ($message) => ['role' => $message->role->value, 'content' => $message->content])
                    ->toArray(),
                ['role' => 'user', 'content' => $user_input],
            ],
        ]);

        $result = $this->bedrock_client->invokeModel([
            'modelId' => static::BEDROCK_MODEL_ID,
            'contentType' => 'application/json',
            'accept' => 'application/json',
            'body' => $body,
        ]);

        $response = json_decode((string) $result['body'], true);

        $decoded_model_response = json_decode($response['content'][0]['text'], true, flags: JSON_THROW_ON_ERROR);

        return [
            'complexity_factor' => (float) $decoded_model_response['complexity_factor'],
            'mode' => $decoded_model_response['mode'],
        ];
    }
}
