<?php

namespace App\Data;

use App\Data\Conversation\MessageRole;
use Spatie\LaravelData\Data;

class ConversationMessageData extends Data
{
    public function __construct(
        public string $pk,
        public string $sk,
        public string $content,
        public MessageRole $role,
        public string $type,
    ) {}
}
