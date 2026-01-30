<?php

namespace App\Handlers;

use App\Contracts\AiClone\MessagesRepository;
use App\Contracts\ReplyStrategy;
// use App\Repositories\AiClone\MessagesRepository;
use Bref\Context\Context;
use Bref\Event\Handler;

class ReplyStrategyHandler implements Handler
{
    public function __construct(
        protected ReplyStrategy $service,
        protected MessagesRepository $messages,
    ) {}

    public function handle(mixed $event, Context $context): array
    {
        $user_input = $event['userInput'];
        $messages_key = $event['messages_key'] ?? '';

        return $this->service
            ->withMessages($this->messages->all($messages_key))
            ->analyzeInput($user_input);
    }
}
