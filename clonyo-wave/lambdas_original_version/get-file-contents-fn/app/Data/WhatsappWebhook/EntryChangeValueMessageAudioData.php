<?php

namespace App\Data\WhatsappWebhook;

use RuntimeException;
use Spatie\LaravelData\Data;

class EntryChangeValueMessageAudioData extends Data
{
    public function __construct(
        public string $id,
        public string $mime_type,
        public string $sha256,
        public bool $voice
    ) {}

    public function getFileName(): string
    {
        return "{$this->id}.{$this->getExtenstionFromMimeType()}";
    }

    protected function getExtenstionFromMimeType(): string
    {
        if (str($this->mime_type)->startsWith('audio/')) {
            return str($this->mime_type)->after('audio/')->before(';');
        } else {
            throw new RuntimeException('Unknown mime type: '.$this->mime_type);
        }
    }
}
