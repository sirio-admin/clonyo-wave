<?php

namespace App\Handlers;

use Bref\Context\Context;
use Bref\Event\Handler;

class GetFileContentsHandler implements Handler
{
    public function handle(mixed $event, Context $context): array
    {
        $file_uri = $event['file_uri'];
        $content = file_get_contents($file_uri);

        return [
            'file_uri' => $file_uri,
            'content' => $content,
        ];
    }
}
