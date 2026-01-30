<?php

namespace App\Contracts\AiClone;

use Illuminate\Support\Collection;

interface MessagesRepository
{
    /**
     * @return Collection<\App\Data\ConversationMessageData>
     */
    public function all(string $key_value, string $key_name = self::KEY_NAME, string $range_key_name = self::RANGE_KEY_NAME): Collection;
}
