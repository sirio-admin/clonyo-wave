<?php

namespace App\Data\AiClone\Config;

use Spatie\LaravelData\Dto;

class ResponseGeneratorData extends Dto
{
    public function __construct(
        public ?string $knowledge_base_id,
        public ?string $system_prompt,

        public ?int $retrieval_results,
        public ?float $temperature,
        public ?int $max_tokens,
    ) {
        $this->knowledge_base_id ??= config('ai-clone.response_generator.default_options.knowledge_base_id');
        $this->system_prompt ??= config('ai-clone.response_generator.default_options.system_prompt');

        $this->retrieval_results ??= config('ai-clone.response_generator.default_options.retrieval_results');
        $this->temperature ??= config('ai-clone.response_generator.default_options.temperature');
        $this->max_tokens ??= config('ai-clone.response_generator.default_options.max_tokens');
    }
}
