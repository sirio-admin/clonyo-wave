<?php

namespace App\Data;

use Spatie\LaravelData\Data;

class MetaPhoneNumberIdData extends Data
{
    public function __construct(
        public string $arn,
        public string $metaPhoneNumberId
    ) {}
}
