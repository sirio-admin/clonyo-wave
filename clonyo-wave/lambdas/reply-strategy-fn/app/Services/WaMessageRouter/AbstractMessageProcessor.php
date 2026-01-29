<?php

namespace App\Services\WaMessageRouter;

use App\Contracts\AiClone\ConfigRepository;
use App\Data\AiClone\Config\ConfigData;
use App\Data\MessageData;
use Arr;
use Log;
use Ramsey\Uuid\Uuid;

abstract class AbstractMessageProcessor
{
    protected MessageData $message;

    public function forMessage(MessageData $message): static
    {
        $this->message = $message;

        return $this;
    }

    protected function getSfnExecutionName(): string
    {
        return str($this->getConfig()->name)->kebab().'_'.Uuid::uuid4();
    }

    protected function getSfnArn(): string
    {
        $from_wa_id = $this->message->whatsAppWebhookEntry->getFromWaId();
        $dev_wa_ids = collect(config('ai-clone.router.wa_message_processor.dev.wa_ids'));

        if ($dev_wa_ids->contains($from_wa_id)) {
            return config('ai-clone.router.wa_message_processor.dev.sfn_arn');
        }

        return config('ai-clone.router.wa_message_processor.live.sfn_arn');
    }

    protected function startStateMachine(array $base_input): void
    {
        $sfn_arn = $this->getSfnArn();

        Log::info("Starting state machine $sfn_arn", [
            'sfn-input' => $input = $this->enrichSfnInput($base_input),
        ]);

        app(\Aws\Sfn\SfnClient::class)
            ->startExecution([
                'stateMachineArn' => $sfn_arn,
                'name' => $this->getSfnExecutionName(),
                'input' => json_encode($input),
            ]);
    }

    protected function getConfig(): ConfigData
    {
        return app(ConfigRepository::class)
            ->get($this->message->getOriginationPhoneNumberId());
    }

    protected function enrichSfnInput(array $base_input): array
    {
        return Arr::collapse([
            $base_input,
            [
                'message_ts' => $this->message->whatsAppWebhookEntry->getReceivedMessage()->timestamp,

                'reply_to_wa_id' => $this->message->whatsAppWebhookEntry->getReplyTo(),
                'wa_contact' => $this->message->whatsAppWebhookEntry->getContact()->toArray(),
                'config' => Arr::from($this->getConfig()),
            ],
        ]);
    }

    abstract public function process(?MessageData $message = null): void;

    protected function logError(string $message): void
    {
        Log::error($message, [
            'message' => json_encode($this->message),
        ]);
    }
}
