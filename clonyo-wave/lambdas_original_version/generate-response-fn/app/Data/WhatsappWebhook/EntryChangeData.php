<?php

namespace App\Data\WhatsappWebhook;

use Spatie\LaravelData\Data;

class EntryChangeData extends Data
{
    public function __construct(
        public string $field,
        public EntryChangeValueData $value
    ) {}
}
