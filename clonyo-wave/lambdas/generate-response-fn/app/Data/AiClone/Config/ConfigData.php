<?php

namespace App\Data\AiClone\Config;

use App\Traits\CanBeJsonEncoded;
use Spatie\LaravelData\Dto;

class ConfigData extends Dto
{
    use CanBeJsonEncoded;

    public function __construct(
        public string $wa_phone_number_arn,
        public string $name,
        public ResponseGeneratorData $response_generator,
        public TextToSpeechData $text_to_speech,
    ) {}

    public static function newFrom(string $wa_phone_number_arn, string $name): self
    {
        return static::from([
            'wa_phone_number_arn' => $wa_phone_number_arn,
            'name' => $name,
            'response_generator' => [],
            'text_to_speech' => [],
        ]);
    }
}
