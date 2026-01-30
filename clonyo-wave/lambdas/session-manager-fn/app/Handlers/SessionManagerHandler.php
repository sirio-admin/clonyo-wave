<?php

namespace App\Handlers;

use Aws\DynamoDb\DynamoDbClient;
use Aws\DynamoDb\Marshaler;
use Bref\Context\Context;
use Bref\Event\Handler;
use Illuminate\Support\Str;

class SessionManagerHandler implements Handler
{
    private DynamoDbClient $dynamoDb;
    private Marshaler $marshaler;

    public function __construct()
    {
        $this->dynamoDb = new DynamoDbClient([
            'region' => $_ENV['AWS_REGION'] ?? 'eu-west-1',
            'version' => 'latest',
            'endpoint' => $_ENV['AWS_ENDPOINT_URL'] ?? null, // Essential for LocalStack
        ]);
        $this->marshaler = new Marshaler();
    }

    public function handle(mixed $event, Context $context): array
    {
        // Extract inputs (adapt based on SFN input structure)
        $wa_contact_id = $event['wa_contact_id'] ?? null;
        
        if (!$wa_contact_id) {
            throw new \Exception("Missing wa_contact_id");
        }

        $tableName = 'sidea-ai-clone-prod-sessions';
        $now = time();
        $thirtyMinutesMsg = 30 * 60;

        // Query for the last session of this user
        // Assuming we have a GSI on wa_contact_id or we query main table if PK is user_id (Plan said PK=session_id, GSI=wa_contact_id)
        
        $response = $this->dynamoDb->query([
            'TableName' => $tableName,
            'IndexName' => 'wa_contact_id_index',
            'KeyConditionExpression' => 'wa_contact_id = :contact_id',
            'ExpressionAttributeValues' => [
                ':contact_id' => ['S' => $wa_contact_id]
            ],
            'Limit' => 1,
            'ScanIndexForward' => false, // Get latest
        ]);

        $items = $response['Items'] ?? [];
        $latestSession = $items[0] ?? null;

        $sessionId = null;
        $topicId = null;
        $isNewSession = true;

        if ($latestSession) {
            $unmarshaled = $this->marshaler->unmarshalItem($latestSession);
            $lastActive = $unmarshaled['last_active_at'] ?? 0;
            
            if (($now - $lastActive) < $thirtyMinutesMsg) {
                // Resume session
                $sessionId = $unmarshaled['session_id'];
                $topicId = $unmarshaled['current_topic_id'] ?? null;
                $isNewSession = false;
            } else {
                // Session expired, recycle topic_id as "contex" but create new session?
                // Plan said: "Mantiene topic_id dell'ultima sessione come 'contesto pregresso' ma ne valuterà uno nuovo"
                $topicId = $unmarshaled['current_topic_id'] ?? null;
            }
        }

        if (!$sessionId) {
            $sessionId = (string) Str::uuid();
            // Create new session entry
            $this->dynamoDb->putItem([
                'TableName' => $tableName,
                'Item' => $this->marshaler->marshalJson(json_encode([
                    'session_id' => $sessionId,
                    'wa_contact_id' => $wa_contact_id,
                    'started_at' => $now,
                    'last_active_at' => $now,
                    'status' => 'ACTIVE',
                    'current_topic_id' => $topicId // Carry over topic or null
                ]))
            ]);
        } else {
             // Update last_active_at
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
            'topic_id' => $topicId, // Might be updated later by AnalyzeTopic
            'is_new_session' => $isNewSession
        ];
    }
}
