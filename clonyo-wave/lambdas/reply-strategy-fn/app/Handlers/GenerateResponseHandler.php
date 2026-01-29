<?php

namespace App\Handlers;

use App\Contracts\AiClone\MessagesRepository;
use App\Contracts\ResponseGenerator;
use App\Data\AiClone\Config\ResponseGeneratorData;
use Bref\Context\Context;
use Bref\Event\Handler;

class GenerateResponseHandler implements Handler
{
    public function __construct(
        protected ResponseGenerator $service,
        protected MessagesRepository $messages
    ) {}

    public function handle(mixed $event, Context $context): array
    {
        $user_input = $event['userInput'];
        $raw_config = $event['config'];
        $with_context = $event['with_context'] ?? true;
        $messages_key = $event['messages_key'] ?? '';

        $response = $this->service
            ->withConfig(ResponseGeneratorData::from($raw_config))
            ->withContext($with_context)
            ->withMessages($this->messages->all($messages_key))
            ->generate($user_input);

        return [
            'response' => $response,
        ];
    }
}
