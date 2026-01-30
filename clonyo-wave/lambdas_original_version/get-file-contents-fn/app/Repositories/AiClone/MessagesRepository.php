<?php

namespace App\Repositories\AiClone;

use App\Data\AiClone\Config\ConfigData;
use App\Data\ConversationMessageData;
use Aws\DynamoDb\DynamoDbClient;
use Aws\DynamoDb\Marshaler;
use Aws\Exception\AwsException;
use Illuminate\Support\Collection;
use Log;

class MessagesRepository implements \App\Contracts\AiClone\MessagesRepository
{
    public const KEY_NAME = 'pk';

    public const RANGE_KEY_NAME = 'sk';

    public function __construct(
        protected string $table_name,
        protected DynamoDbClient $client,
        protected Marshaler $marshaler
    ) {}

    /**
     * @return Collection<\App\Data\ConversationMessageData>
     */
    public function all(string $key_value, string $key_name = self::KEY_NAME, string $range_key_name = self::RANGE_KEY_NAME): Collection
    {
        $result = $this->client->query([
            'TableName' => $this->table_name,
            'KeyConditionExpression' => "$key_name = :pk AND begins_with($range_key_name, :sk)",
            'ExpressionAttributeValues' => [
                ':pk' => ['S' => $key_value],
                ':sk' => ['S' => 'M#'],
            ],
        ]);

        $items = $result->get('Items');

        // dd($items);

        if (empty($items)) {
            return collect();
        }

        //         return ConversationMessageData::collect(
        //             collect($items)
        // ->map(fn ($item) => $this->marshaler->unmarshalItem($item))
        //                 ->toArray()
        //         )

        return collect($items)
            ->map(fn ($item) => ConversationMessageData::from($this->marshaler->unmarshalItem($item)));

        // return ConfigData::from($this->marshaler->unmarshalItem($item));
    }

    // public function put(ConfigData $config): bool
    // {
    //     try {
    //         $result = $this->client->putItem([
    //             'TableName' => $this->table_name,
    //             'Item' => $this->marshaler->marshalJson($config->jsonEncode()),
    //         ]);

    //         return $result->get('@metadata')['statusCode'] == 200;
    //     } catch (AwsException $exception) {
    //         Log::error($exception->getMessage(), [
    //             'exception' => $exception->toArray(),
    //         ]);

    //         return false;
    //     }
    // }
}
