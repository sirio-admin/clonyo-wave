<?php

namespace App\Contracts;

use App\Data\AiClone\Config\TextToSpeechData;
use Bref\Context\Context;

interface TextToSpeechConverter
{
    public function withConfig(TextToSpeechData $config): static;

    public function withLambdaContext(Context $context): static;

    public function forWaPhoneNumberArn(string $wa_phone_number_arn): static;

    public function convertAndSaveToS3(string $user_input, string $output_filename): array;
}
