<?php

namespace App\Data\WhatsappWebhook;

use Spatie\LaravelData\Data;

class EntryChangeValueMessageData extends Data
{
    public function __construct(
        public string $from,
        public string $id,
        public string $timestamp,
        public ?EntryChangeValueMessageTextData $text,
        public ?EntryChangeValueMessageAudioData $audio,
        public MessageType $type
    ) {}
}
