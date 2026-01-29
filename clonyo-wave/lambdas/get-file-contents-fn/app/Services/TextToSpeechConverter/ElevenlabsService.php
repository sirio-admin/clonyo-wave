<?php

namespace App\Services\TextToSpeechConverter;

use App\Contracts\TextToSpeechConverter;
use App\Data\AiClone\Config\TextToSpeechData;
use App\Services\WaMedia\PathGenerationInteface;
use App\Services\WaMedia\PathGenerationType;
use Bref\Context\Context;
use Http;
use Illuminate\Support\Facades\Storage;

class ElevenlabsService implements TextToSpeechConverter
{
    protected const BASE_URL = 'https://api.elevenlabs.io/v1/';

    protected TextToSpeechData $config;

    protected Context $context;

    protected string $destination_bucket_name;

    protected string $wa_phone_number_arn;

    public function __construct(
        protected PathGenerationInteface $path_generator,
    ) {
        $this->destination_bucket_name = config('ai-clone.commons.wa_media.bucket_name');
        $this->path_generator
            ->forBucketName($this->destination_bucket_name)
            ->forType(PathGenerationType::AUDIO_OUT);
    }

    public function withConfig(TextToSpeechData $config): static
    {
        $this->config = $config;

        return $this;
    }

    public function withLambdaContext(Context $context): static
    {
        $this->context = $context;

        return $this;
    }

    public function forWaPhoneNumberArn(string $wa_phone_number_arn): static
    {
        $this->wa_phone_number_arn = $wa_phone_number_arn;

        return $this;
    }

    public function convertAndSaveToS3(
        string $user_input,
        string $output_filename_without_ext
    ): array {
        $output_filename = $output_filename_without_ext.'.'.$this->config->guessFileExtFromOutputFormat();

        // Init path generator
        $this->path_generator
            ->forWaPhoneNumberArn($this->wa_phone_number_arn)
            ->forFilename($output_filename);

        $audio = $this->generateAudioResource($user_input);

        $this->saveStreamToS3($output_filename, $audio);

        return [
            'bucket_name' => $this->destination_bucket_name,
            'key' => $this->path_generator->buildPath(),
        ];
    }

    protected function getHttpRequestTimeout($default = 30): int
    {
        return min([
            $this->config->request_timeout,
            $this->context->getRemainingTimeInMillis() / 1000 - 1,
        ]) ?: $default;
    }

    protected function generateAudioResource(string $text)
    {
        $response = Http::baseUrl(static::BASE_URL)
            ->timeout($this->getHttpRequestTimeout())
            ->withHeaders([
                'content-type' => 'application/json',
                'xi-api-key' => $this->config->api_key,
            ])
            ->withQueryParameters([
                'output_format' => $this->config->output_format,
            ])
            ->post("text-to-speech/{$this->config->voice_id}/stream", [
                'text' => $text,
                'voice_settings' => $this->config->getVoiceSettingsForElevenLabs(),
            ]);

        return $response->resource();
    }

    protected function saveStreamToS3(string $filename, $stream)
    {
        $fs = Storage::build([
            'driver' => 's3',
            'bucket' => $this->destination_bucket_name,
        ]);

        $fs->put(
            $this->path_generator->buildPath(),
            $stream
        );
    }
}
