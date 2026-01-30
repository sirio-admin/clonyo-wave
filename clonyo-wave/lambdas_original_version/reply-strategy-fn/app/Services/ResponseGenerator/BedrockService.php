<?php

namespace App\Services\ResponseGenerator;

use App\Contracts\ResponseGenerator;
use App\Data\AiClone\Config\ResponseGeneratorData;
use App\Data\ConversationMessageData;
use Aws\BedrockRuntime\BedrockRuntimeClient;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;

class BedrockService implements ResponseGenerator
{
    protected const BEDROCK_MODEL_ID = 'eu.anthropic.claude-3-5-sonnet-20240620-v1:0';

    protected const ANTHROPIC_VERSION = 'bedrock-2023-05-31';

    protected bool $with_context = false;

    /**
     * @var Collection<ConversationMessageData>
     */
    protected Collection $messages;

    protected ResponseGeneratorData $config;

    public function __construct(
        protected ContextRetriver $context_retriver,
        protected BedrockRuntimeClient $bedrock_client
    ) {
        $this->messages = collect();
    }

    public function withConfig(ResponseGeneratorData $config): static
    {
        $this->config = $config;

        return $this;
    }

    public function withContext(bool $with_context = true): static
    {
        $this->with_context = $with_context;

        return $this;
    }

    public function withMessages(Collection $messages): static
    {
        $this->messages = collect($messages)->take(-10);

        return $this;
    }

    protected function getUserContent(string $user_input): string
    {
        if ($this->with_context) {
            $context_contents = $this->context_retriver->withConfig($this->config)->retrive($user_input);
            $context = Arr::join($context_contents, "\n\n");
            $context .= <<<CONTEXT
INIZIO Contesto
$context
FINE Contesto
CONTEXT;
        }

        return ($context ?? '')."\n".<<<CONTENT
Domanda:
$user_input
CONTENT;
    }

    public function generate(string $user_input): string
    {
        $body = json_encode([
            'anthropic_version' => static::ANTHROPIC_VERSION,
            'temperature' => $this->config->temperature,
            'max_tokens' => $this->config->max_tokens,
            'system' => $this->config->system_prompt, // contesto rimosso dal system prompt per ottimizzare caching
            'messages' => [
                ...collect($this->messages)
                    ->map(fn ($message) => ['role' => $message->role->value, 'content' => $message->content])
                    ->toArray(),
                ['role' => 'user', 'content' => $this->getUserContent($user_input)],
            ],
        ]);

        $result = $this->bedrock_client->invokeModel([
            'modelId' => static::BEDROCK_MODEL_ID,
            'contentType' => 'application/json',
            'accept' => 'application/json',
            'body' => $body,
        ]);

        $response = json_decode((string) $result['body'], true);

        return $response['content'][0]['text'];
    }
}
