<?php

namespace App\Services\WaMedia;

use Arr;
use Illuminate\Support\Stringable;
use Str;

class PathGenerationService implements PathGenerationInteface
{
    protected PathGenerationType $type;

    protected string $bucket_name;

    protected string $wa_phone_number_arn;

    protected string $filename;

    public function forBucketName(string $bucket_name): static
    {
        $this->bucket_name = $bucket_name;

        return $this;
    }

    public function forFilename(string $filename): static
    {
        $this->filename = $filename;

        return $this;
    }

    public function forType(PathGenerationType $type): static
    {
        $this->type = $type;

        return $this;
    }

    public function forWaPhoneNumberArn(string $wa_phone_number_arn): static
    {
        $this->wa_phone_number_arn = $wa_phone_number_arn;

        return $this;
    }

    public function buildPrefix(): Stringable
    {
        return str(Arr::join(
            [
                $this->getPhoneNumberId(),
                // $this->getAccountId(),
                // $this->getPhoneNumberId(),
                $this->type->value,
            ],
            '/'
        ))->finish('/');
    }

    public function buildPath(?string $filename = null): Stringable
    {
        if (! empty($filename)) {
            $this->forFilename($filename);
        }

        return $this->buildPrefix()->finish($this->filename);
    }

    public function buildS3Uri(?string $filename = null): Stringable
    {
        if (! empty($filename)) {
            $this->forFilename($filename);
        }

        return str("s3://{$this->bucket_name}/{$this->buildPath()}");
    }

    // protected function getAccountId(): string
    // {
    //     return str($this->wa_phone_number_arn)->before(":phone-number-id")->afterLast(":");
    // }

    protected function getPhoneNumberId(): string
    {
        return str($this->wa_phone_number_arn)->afterLast('/');
    }
}
