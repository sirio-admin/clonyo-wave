<?php

namespace App\Data\AiClone\Config;

use RuntimeException;
use Spatie\LaravelData\Dto;

class TextToSpeechData extends Dto
{
    public function __construct(
        public ?string $api_key,
        public ?string $voice_id,

        public ?string $output_format,
        public ?float $stability,
        public ?bool $use_speaker_boost,
        public ?float $similarity_boost,
        public ?float $style,
        public ?float $speed,
        public ?int $request_timeout,
    ) {
        $this->api_key ??= config('ai-clone.text_to_speech.default_options.api_key');
        $this->voice_id ??= config('ai-clone.text_to_speech.default_options.voice_id');

        $this->output_format ??= config('ai-clone.text_to_speech.default_options.output_format');
        $this->stability ??= config('ai-clone.text_to_speech.default_options.stability');
        $this->use_speaker_boost ??= config('ai-clone.text_to_speech.default_options.use_speaker_boost');
        $this->similarity_boost ??= config('ai-clone.text_to_speech.default_options.similarity_boost');
        $this->style ??= config('ai-clone.text_to_speech.default_options.style');
        $this->speed ??= config('ai-clone.text_to_speech.default_options.speed');

        $this->request_timeout ??= config('ai-clone.text_to_speech.default_options.request_timeout');
    }

    public function guessFileExtFromOutputFormat(): string
    {
        if (str($this->output_format)->startsWith('opus')) {
            return 'ogg';
        }

        throw new RuntimeException("Can't guess extension for $this->output_format");
    }

    public function getVoiceSettingsForElevenLabs(): array
    {
        return [
            'stability' => $this->stability,
            'use_speaker_boost' => $this->use_speaker_boost,
            'similarity_boost' => $this->similarity_boost,
            'style' => $this->style,
            'speed' => $this->speed,
        ];
    }
}
