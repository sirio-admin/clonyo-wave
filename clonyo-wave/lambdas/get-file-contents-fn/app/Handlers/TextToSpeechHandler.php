<?php

namespace App\Handlers;

use App\Contracts\TextToSpeechConverter;
use App\Data\AiClone\Config\TextToSpeechData;
use Bref\Event\Handler;

class TextToSpeechHandler implements Handler
{
    public function __construct(
        protected TextToSpeechConverter $service,
    ) {}

    public function handle(mixed $event, \Bref\Context\Context $context): array
    {
        $text = $event['text'];
        $config = $event['config'];
        $wa_phone_number_arn = $event['wa_phone_number_arn'];

        $result = $this->service
            ->forWaPhoneNumberArn($wa_phone_number_arn)
            ->withConfig(TextToSpeechData::from($config))
            ->withLambdaContext($context)
            ->convertAndSaveToS3($text, $context->getAwsRequestId());

        return $result;
    }
}
