<?php

namespace App\Repositories\AiClone;

use App\Data\AiClone\Config\ConfigData;
use Aws\DynamoDb\DynamoDbClient;
use Aws\DynamoDb\Marshaler;
use Aws\Exception\AwsException;
use Log;

class ConfigRepository implements \App\Contracts\AiClone\ConfigRepository
{
    public const KEY_NAME = 'wa_phone_number_arn';

    public function __construct(
        protected string $table_name,
        protected DynamoDbClient $client,
        protected Marshaler $marshaler
    ) {}

    public function get(string $key_value, string $key_name = self::KEY_NAME): ?ConfigData
    {
        $result = $this->client->getItem([
            'TableName' => $this->table_name,
            'Key' => [
                $key_name => [
                    'S' => $key_value,
                ],
            ],
        ]);

        $item = $result->get('Item');

        if (empty($item)) {
            return null;
        }

        return ConfigData::from($this->marshaler->unmarshalItem($item));
    }

    public function put(ConfigData $config): bool
    {
        try {
            $result = $this->client->putItem([
                'TableName' => $this->table_name,
                'Item' => $this->marshaler->marshalJson($config->jsonEncode()),
            ]);

            return $result->get('@metadata')['statusCode'] == 200;
        } catch (AwsException $exception) {
            Log::error($exception->getMessage(), [
                'exception' => $exception->toArray(),
            ]);

            return false;
        }
    }
}
