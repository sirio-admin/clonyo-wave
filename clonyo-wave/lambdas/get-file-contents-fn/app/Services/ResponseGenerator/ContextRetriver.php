<?php

namespace App\Services\ResponseGenerator;

use App\Data\AiClone\Config\ResponseGeneratorData;
use Aws\BedrockAgentRuntime\BedrockAgentRuntimeClient;

class ContextRetriver
{
    protected ResponseGeneratorData $config;

    public function __construct(
        protected BedrockAgentRuntimeClient $bedrock_agent_client
    ) {}

    public function withConfig(ResponseGeneratorData $config): static
    {
        $this->config = $config;

        return $this;
    }

    public function retrive(string $user_input): array
    {
        $result = $this->bedrock_agent_client->retrieve([
            'knowledgeBaseId' => $this->config->knowledge_base_id,
            'retrievalConfiguration' => [
                'vectorSearchConfiguration' => [
                    'numberOfResults' => $this->config->retrieval_results,
                ],
            ],
            'retrievalQuery' => [
                'text' => $user_input,
            ],
        ]);

        return collect($result['retrievalResults'])
            ->map(fn ($doc) => $doc['content']['text'])
            ->toArray();
    }
}
