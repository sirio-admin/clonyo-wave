<?php

namespace App\Services\WaMessageRouter;

use App\Data\MessageData;

class TextMessageProcessor extends AbstractMessageProcessor
{
    public function process(?MessageData $message = null): void
    {
        if (! empty($message)) {
            $this->forMessage($message);
        }

        $this->startStateMachine([
            'text' => [
                'body' => $this->message->whatsAppWebhookEntry->getReceivedTextMessage()->body,
            ],
        ]);
    }
}
