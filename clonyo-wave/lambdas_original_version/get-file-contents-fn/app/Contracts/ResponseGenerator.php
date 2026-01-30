<?php

namespace App\Contracts;

use App\Data\AiClone\Config\ResponseGeneratorData;
use Illuminate\Support\Collection;

interface ResponseGenerator
{
    public function withConfig(ResponseGeneratorData $config): static;

    public function withContext(bool $with_context = true): static;

    public function withMessages(Collection $messages): static;

    public function generate(string $user_input): string;
}
