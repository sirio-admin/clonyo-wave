<?php

namespace App\Data;

use Spatie\LaravelData\Attributes\DataCollectionOf;
use Spatie\LaravelData\Data;
use Spatie\LaravelData\DataCollection;

class MessageContextData extends Data
{
    public function __construct(
        #[DataCollectionOf(MetaPhoneNumberIdData::class)]
        public DataCollection $MetaPhoneNumberIds,
        public array $MetaWabaIds
    ) {}
}
