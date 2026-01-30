<?php

namespace App\Services\WaMedia;

use Illuminate\Support\Stringable;

interface PathGenerationInteface
{
    public function forType(PathGenerationType $type): static;

    public function forFilename(string $filename): static;

    public function forBucketName(string $bucket_name): static;

    public function forWaPhoneNumberArn(string $wa_phone_number_arn): static;

    public function buildPrefix(): Stringable;

    public function buildPath(?string $filename = null): Stringable;

    public function buildS3Uri(?string $filename = null): Stringable;
}
