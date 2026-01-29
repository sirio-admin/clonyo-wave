<?php

namespace App\Data\Conversation;

enum MessageRole: string
{
    case USER = 'user';
    case ASSISTANT = 'assistant';
}
