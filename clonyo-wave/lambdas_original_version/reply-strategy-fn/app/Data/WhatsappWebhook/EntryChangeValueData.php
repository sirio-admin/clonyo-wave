<?php

namespace App\Data\WhatsappWebhook;

use Spatie\LaravelData\Attributes\DataCollectionOf;
use Spatie\LaravelData\Data;
use Spatie\LaravelData\DataCollection;

class EntryChangeValueData extends Data
{
    public function __construct(
        public string $messaging_product,
        public EntryChangeValueMetadataData $metadata,
        #[DataCollectionOf(EntryChangeValueContactData::class)]
        public ?DataCollection $contacts,
        #[DataCollectionOf(EntryChangeValueMessageData::class)]
        public ?DataCollection $messages,
        public ?array $statuses
    ) {}
}
