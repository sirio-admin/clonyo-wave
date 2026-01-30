<?php

namespace App\Data;

use Spatie\LaravelData\Data;

class MessageData extends Data
{
    public function __construct(
        public string $aws_account_id,
        public MessageContextData $context,
        public string $message_timestamp,
        public WhatsappWebhook\EntryData $whatsAppWebhookEntry,
    ) {}

    public function getOriginationPhoneNumberId(): string
    {
        return $this->context->MetaPhoneNumberIds[0]?->arn;
    }
}
