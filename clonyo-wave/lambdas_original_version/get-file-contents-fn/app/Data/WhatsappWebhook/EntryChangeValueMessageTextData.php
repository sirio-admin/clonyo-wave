<?php

namespace App\Data\WhatsappWebhook;

use Spatie\LaravelData\Data;

class EntryChangeValueMessageTextData extends Data
{
    public function __construct(
        public string $body
    ) {}
}
