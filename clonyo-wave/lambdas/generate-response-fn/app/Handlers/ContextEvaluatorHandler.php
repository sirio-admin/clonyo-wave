<?php

namespace App\Handlers;

use Aws\BedrockRuntime\BedrockRuntimeClient;
use Bref\Context\Context;
use Bref\Event\Handler;
use Illuminate\Support\Facades\Log;

class ContextEvaluatorHandler implements Handler
{
    public function __construct(
        protected BedrockRuntimeClient $bedrock
    ) {}

    public function handle(mixed $event, Context $context): array
    {
        $userInput = $event['userInput'] ?? '';
        $history = $event['history'] ?? [];

        if (empty($history)) {
            return ['sufficient' => false];
        }

        $historyText = is_array($history) ? json_encode($history) : $history;

        $systemPrompt = "You are a context judge. Given a User Question and a set of Retrieved Memory/Context, decide if the Memory is sufficient to answer the question well.
        If yes, output {\"sufficient\": true}. If the Memory is irrelevant or empty and the question requires factual knowledge, output {\"sufficient\": false}.";

        $prompt = "Question: $userInput\nMemory: $historyText";

        $body = [
            'anthropic_version' => 'bedrock-2023-05-31',
            'max_tokens' => 100,
            'system' => $systemPrompt,
            'messages' => [
                ['role' => 'user', 'content' => $prompt]
            ]
        ];

        try {
            $result = $this->bedrock->invokeModel([
                'modelId' => 'anthropic.claude-3-haiku-20240307-v1:0',
                'contentType' => 'application/json',
                'body' => json_encode($body)
            ]);

            $response = json_decode($result['body']->getContents(), true);
            $content = json_decode($response['content'][0]['text'], true);

            return [
                'sufficient' => $content['sufficient'] ?? false
            ];

        } catch (\Exception $e) {
            Log::error("Context evaluator error", ['error' => $e->getMessage()]);
            return ['sufficient' => false];
        }
    }
}
