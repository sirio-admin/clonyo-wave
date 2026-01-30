<?php

namespace App\Handlers;

use App\Services\WaMessageRouter\Service;
use Bref\Event\Sqs\SqsHandler;
use Log;

class WaMessageRouterHandler extends SqsHandler
{
    public function __construct(
        protected Service $service,
    ) {}

    public function handleSqs(\Bref\Event\Sqs\SqsEvent $event, \Bref\Context\Context $context): void
    {
        $records = $event->getRecords();

        foreach ($records as $record) {
            Log::debug($record->getBody());

            $json = json_decode($record->getBody(), true);
            $message = json_decode($json['Message'], true);

            $this->service->process($message);
        }
    }
}
