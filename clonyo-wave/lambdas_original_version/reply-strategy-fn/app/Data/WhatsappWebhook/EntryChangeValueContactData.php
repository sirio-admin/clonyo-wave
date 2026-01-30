<?php

namespace App\Data\WhatsappWebhook;

use Spatie\LaravelData\Data;

class EntryChangeValueContactData extends Data
{
    public function __construct(
        public array $profile,
        public string $wa_id
    ) {}
}
