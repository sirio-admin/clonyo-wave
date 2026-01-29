<?php

namespace App\Data\WhatsappWebhook;

enum MessageType: string
{
    case TEXT = 'text';
    case AUDIO = 'audio';
}
