<?php

namespace App\Services\WaMessageRouter;

use App\Data\MessageData;
use App\Services\WaMedia\PathGenerationInteface;
use App\Services\WaMedia\PathGenerationType;
use Aws\Result;
use Aws\SocialMessaging\SocialMessagingClient;

class AudioMessageProcessor extends AbstractMessageProcessor
{
    protected string $destination_bucket_name;

    public function __construct(
        protected PathGenerationInteface $path_generator,
        protected SocialMessagingClient $social_messaging_client,
    ) {
        $this->destination_bucket_name = config('ai-clone.commons.wa_media.bucket_name');

        $this->path_generator
            ->forType(PathGenerationType::AUDIO_IN)
            ->forBucketName($this->destination_bucket_name);
        // ->forFilename($this->message->whatsAppWebhookEntry->getReceivedAudioMessage()->getFileName())
    }

    protected function getS3Uri(): string
    {
        return $this->path_generator
            ->forWaPhoneNumberArn($this->message->getOriginationPhoneNumberId())
            ->forFilename($this->message->whatsAppWebhookEntry->getReceivedAudioMessage()->getFileName())
            ->buildS3Uri();
    }

    protected function getS3Prefix(): string
    {
        return $this->path_generator
            ->forWaPhoneNumberArn($this->message->getOriginationPhoneNumberId())
            ->buildPrefix();
    }

    public function process(?MessageData $message = null): void
    {
        if (! empty($message)) {
            $this->forMessage($message);
        }

        $this->saveWaMedia();

        $this->startStateMachine([
            'audio' => [
                's3_uri' => $this->getS3Uri(),
            ],
        ]);
    }

    protected function saveWaMedia(): Result
    {
        return $this->social_messaging_client->getWhatsAppMessageMedia([
            'destinationS3File' => [
                'bucketName' => $this->destination_bucket_name,
                'key' => $this->getS3Prefix(),
            ],
            'mediaId' => $this->message->whatsAppWebhookEntry->getReceivedAudioMessage()->id,
            'originationPhoneNumberId' => $this->message->getOriginationPhoneNumberId(),
        ]);
    }
}
