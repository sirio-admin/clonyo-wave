<?php

namespace App\Providers;

use App\Repositories\AiClone\ConfigRepository;
use App\Repositories\AiClone\MessagesRepository;
use App\Services\WaMedia\PathGenerationInteface;
use App\Services\WaMedia\PathGenerationService;
use Aws\BedrockAgentRuntime\BedrockAgentRuntimeClient;
use Aws\BedrockRuntime\BedrockRuntimeClient;
use Aws\DynamoDb\DynamoDbClient;
use Aws\Sfn\SfnClient;
use Aws\SocialMessaging\SocialMessagingClient;
use Illuminate\Foundation\Application;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(
            PathGenerationInteface::class,
            PathGenerationService::class
        );

        $this->app->singleton(
            DynamoDbClient::class,
            fn () => new DynamoDbClient([])
        );

        $this->app->singleton(
            \Aws\DynamoDb\Marshaler::class,
            fn () => new \Aws\DynamoDb\Marshaler()
        );

        $this->app->singleton(
            \App\Contracts\AiClone\ConfigRepository::class,
            fn (Application $app) => $app->makeWith(ConfigRepository::class, ['table_name' => $app->make('config')->get('ai-clone.router.config_table')])
        );

        $this->app->bind(
            \App\Contracts\ResponseGenerator::class,
            function ($app) {
                $provider = $app->make('config')->get('ai-clone.response_generator.provider');

                return match ($provider) {
                    'bedrock' => $app->make(\App\Services\ResponseGenerator\BedrockService::class),
                    default => throw new \Exception('Unknown response generator provider: '.$provider)
                };
            }
        );

        $this->app->bind(
            \App\Contracts\TextToSpeechConverter::class,
            function ($app) {
                $provider = $app->make('config')->get('ai-clone.text_to_speech.provider');

                return match ($provider) {
                    'elevenlabs' => $app->make(\App\Services\TextToSpeechConverter\ElevenlabsService::class),
                    default => throw new \Exception('Unknown text-2-speech provider: '.$provider)
                };
            }
        );

        $this->app->singleton(
            BedrockRuntimeClient::class,
            fn () => new BedrockRuntimeClient([])
        );

        $this->app->singleton(
            BedrockAgentRuntimeClient::class,
            fn () => new BedrockAgentRuntimeClient([])
        );

        $this->app->singleton(
            SocialMessagingClient::class,
            fn () => new SocialMessagingClient([]),
        );

        $this->app->singleton(
            SfnClient::class,
            fn () => new SfnClient([]),
        );

        $this->app->singleton(
            \App\Contracts\AiClone\MessagesRepository::class,
            function ($app) {
                return $app->makeWith(MessagesRepository::class, ['table_name' => $app->make('config')->get('ai-clone.response_generator.messages_table')]);
            }
        );

        $this->app->singleton(
            \App\Contracts\ReplyStrategy::class,
            \App\Services\ReplyStrategyService::class,
        );
    }
}
