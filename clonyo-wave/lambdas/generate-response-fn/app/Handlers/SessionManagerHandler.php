<?php

namespace App\Handlers;

use Aws\DynamoDb\DynamoDbClient;
use Aws\DynamoDb\Marshaler;
use Bref\Context\Context;
use Bref\Event\Handler;
use Illuminate\Support\Str;

class SessionManagerHandler implements Handler
{
    public function __construct(
        protected DynamoDbClient $dynamoDb,
        protected Marshaler $marshaler
    ) {}

    public function handle(mixed $event, Context $context): array
    {
        $wa_contact_id = $event['wa_contact_id'] ?? null;

        if (!$wa_contact_id) {
            throw new \Exception("Missing wa_contact_id");
        }

        $tableName = config('services.aws.sessions_table', env('WA_SESSIONS_TABLE'));
        $now = time();
        $thirtyMinutes = 30 * 60;

        $response = $this->dynamoDb->query([
            'TableName' => $tableName,
            'IndexName' => 'wa_contact_id_index',
            'KeyConditionExpression' => 'wa_contact_id = :contact_id',
            'ExpressionAttributeValues' => [
                ':contact_id' => ['S' => $wa_contact_id]
            ],
            'Limit' => 1,
            'ScanIndexForward' => false,
        ]);

        $items = $response['Items'] ?? [];
        $latestSession = $items[0] ?? null;

        $sessionId = null;
        $topicId = null;
        $isNewSession = true;

        if ($latestSession) {
            $unmarshaled = $this->marshaler->unmarshalItem($latestSession);
            $lastActive = $unmarshaled['last_active_at'] ?? 0;

            if (($now - $lastActive) < $thirtyMinutes) {
                $sessionId = $unmarshaled['session_id'];
                $topicId = $unmarshaled['current_topic_id'] ?? null;
                $isNewSession = false;
            } else {
                $topicId = $unmarshaled['current_topic_id'] ?? null;
            }
        }

        if (!$sessionId) {
            $sessionId = (string) Str::uuid();
            $this->dynamoDb->putItem([
                'TableName' => $tableName,
                'Item' => $this->marshaler->marshalJson(json_encode([
                    'session_id' => $sessionId,
                    'wa_contact_id' => $wa_contact_id,
                    'started_at' => $now,
                    'last_active_at' => $now,
                    'status' => 'ACTIVE',
                    'current_topic_id' => $topicId
                ]))
            ]);
        } else {
            $this->dynamoDb->updateItem([
                'TableName' => $tableName,
                'Key' => ['session_id' => ['S' => $sessionId]],
                'UpdateExpression' => 'SET last_active_at = :now',
                'ExpressionAttributeValues' => [
                    ':now' => ['N' => (string)$now]
                ]
            ]);
        }

        return [
            'session_id' => $sessionId,
            'topic_id' => $topicId,
            'is_new_session' => $isNewSession
        ];
    }
}
