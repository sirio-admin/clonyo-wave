<?php

namespace App\Handlers;

use Aws\BedrockRuntime\BedrockRuntimeClient;
use Bref\Context\Context;
use Bref\Event\Handler;
use Illuminate\Support\Str;

class AnalyzeTopicHandler implements Handler
{
    private BedrockRuntimeClient $bedrock;

    public function __construct()
    {
        // Bedrock calls must go to Real AWS, so we ignore local endpoint
        $this->bedrock = new BedrockRuntimeClient([
            'region' => 'eu-central-1', // Haiku availability
            'version' => 'latest',
            // Default credential provider will use AWS_* env vars
        ]);
    }

    public function handle(mixed $event, Context $context): array
    {
        $text = $event['text'] ?? '';
        $currentTopicId = $event['current_topic_id'] ?? null;
        
        if (empty($text)) {
             return ['topic_id' => $currentTopicId, 'keywords' => []];
        }

        $systemPrompt = "You are a Topic Analyzer. Analyze the user input. Extract the main topic (1-2 words) and 3 keywords. 
        If a Previous Topic is provided, check if the input is a continuation. If yes, reuse the same Topic ID (if it was passed as keyword, otherwise output the topic name).
        Output ONLY JSON: {\"topic\": \"string\", \"keywords\": [\"string\"]}";

        $prompt = "User Input: $text\nPrevious Topic ID: " . ($currentTopicId ?? 'None');

        // Haiku Payload
        $body = [
            'anthropic_version' => 'bedrock-2023-05-31',
            'max_tokens' => 300,
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
            
            $topicName = $content['topic'] ?? 'General';
            $keywords = $content['keywords'] ?? [];
            
            // Simple logic: if topic name is same as before, keep ID, else generate new
            // In real app, we might use embeddings to check similarity.
            // Here we just map String -> ID (md5) for consistency
            $topicId = md5(strtolower($topicName));

            return [
                'topic_id' => $topicId,
                'topic_name' => $topicName,
                'keywords' => $keywords
            ];

        } catch (\Exception $e) {
            // Fallback
            echo "Bedrock Error: " . $e->getMessage();
            return [
                'topic_id' => $currentTopicId ?? 'general',
                'topic_name' => 'General',
                'keywords' => []
            ];
        }
    }
}
