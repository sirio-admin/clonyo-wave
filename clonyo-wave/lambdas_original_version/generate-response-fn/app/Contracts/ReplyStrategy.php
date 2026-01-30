<?php

namespace App\Contracts;

use Illuminate\Support\Collection;

interface ReplyStrategy
{
    /**
     * @return array<{complexity_factor: float, mode: string}>
     */
    public function analyzeInput(string $user_input): array;

    public function withMessages(Collection $messages): static;
}
