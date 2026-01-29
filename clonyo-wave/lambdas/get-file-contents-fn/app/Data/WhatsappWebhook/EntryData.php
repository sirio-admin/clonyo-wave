<?php

namespace App\Data\WhatsappWebhook;

use Spatie\LaravelData\Attributes\DataCollectionOf;
use Spatie\LaravelData\Data;
use Spatie\LaravelData\DataCollection;

class EntryData extends Data
{
    public function __construct(
        public string $id,
        #[DataCollectionOf(EntryChangeData::class)]
        public DataCollection $changes
    ) {}

    public function getMessageType(): ?MessageType
    {
        if (empty($this->changes[0]?->value?->messages)) {
            return null;
        }

        return $this->changes[0]?->value?->messages[0]?->type;
    }

    public function isTextMessage(): bool
    {
        return $this->getMessageType() === MessageType::TEXT;
    }

    public function isAudioMessage(): bool
    {
        return $this->getMessageType() === MessageType::AUDIO;
    }

    public function getFromWaId(): string
    {
        return $this->changes[0]->value->contacts[0]?->wa_id;
    }

    public function getReplyTo(): string
    {
        return str($this->getFromWaId())->start('+');
    }

    public function getReceivedMessage(
        int $message_index = 0,
        int $change_index = 0,
    ): ?EntryChangeValueMessageData {
        return $this->changes[$change_index]?->value->messages[$message_index];
    }

    public function getReceivedTextMessage(): ?EntryChangeValueMessageTextData
    {
        return $this->getReceivedMessage()?->text;
    }

    public function getReceivedAudioMessage(): ?EntryChangeValueMessageAudioData
    {
        return $this->getReceivedMessage()?->audio;
    }

    /**
     * @param  mixed  $index
     * @return array{
     *     profile: array{name: string},
     *     wa_id: string
     * }
     */
    public function getContact(
        int $contact_index = 0,
        int $change_index = 0,
    ): ?EntryChangeValueContactData {
        return $this->changes[$change_index]?->value->contacts[$contact_index];
    }
}
