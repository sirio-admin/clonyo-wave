<?php

namespace App\Services\WaMessageRouter;

use App\Data\MessageData;
use App\Data\WhatsappWebhook\MessageType;
use Log;

class Service
{
    protected MessageData $message;

    protected array $plain_message;

    public function __construct(
        protected TextMessageProcessor $text_processor,
        protected AudioMessageProcessor $audio_processor
    ) {}

    public function forPlainMessage(array $plain_message): self
    {
        $this->message = MessageData::from($this->plain_message = $plain_message);

        return $this;
    }

    public function process(?array $plain_message = null): void
    {
        if ($plain_message) {
            $this->forPlainMessage($plain_message);
        }

        Log::debug(json_encode($this->plain_message));

        switch ($this->message->whatsAppWebhookEntry->getMessageType()) {
            case MessageType::TEXT:
                $this->text_processor->process($this->message);
                break;
            case MessageType::AUDIO:
                $this->audio_processor->process($this->message);
                break;
            default:
                Log::warning('Unsupported message type');
        }
    }
}
