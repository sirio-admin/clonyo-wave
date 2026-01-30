<?php

namespace App\Data\WhatsappWebhook;

use Spatie\LaravelData\Data;

class EntryChangeValueMetadataData extends Data
{
    public function __construct(
        public string $display_phone_number,
        public string $phone_number_id
    ) {}
}
