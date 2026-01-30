<?php

use App\Services\WaMedia\PathGenerationService;

return [
    'commons' => [
        'wa_media' => [
            'bucket_name' => env('WA_MEDIA_BUCKET_NAME', 'bucket-name'),
            // 'path_generator' => PathGenerationService::class,
        ],
    ],

    'router' => [
        'wa_message_processor' => [
            'live' => [
                'sfn_arn' => str($base_sfn_arn = env('ROUTER_WA_MESSAGE_PROCESSOR_SFN_ARN'))->finish(':live')->toString(),
            ],
            'dev' => [
                'sfn_arn' => $base_sfn_arn,
                'wa_ids' => explode(',', env('ROUTER_DEV_WA_IDS', '')),
            ],
        ],
        'config_table' => env('ROUTER_CONFIG_TABLE', 'config-table'),
    ],

    'response_generator' => [
        'provider' => 'bedrock',

        'default_options' => [
            'knowledge_base_id' => 'MUST_BE_SET',
            'system_prompt' => 'MUST_BE_SET',
            'retrieval_results' => 4,
            'temperature' => 0.5,
            'max_tokens' => 4096,
        ],

        'messages_table' => env('WA_MESSAGES_TABLE', 'messages-table'),
    ],

    'text_to_speech' => [
        'provider' => 'elevenlabs',

        'default_options' => [
            'api_key' => 'MUST_BE_SET',
            'voice_id' => 'MUST_BE_SET',

            'output_format' => 'opus_48000_32',
            'stability' => 0.76,
            'use_speaker_boost' => null,
            'similarity_boost' => 0.88,
            'style' => 0.10,
            'speed' => null,

            'request_timeout' => 58, // secondi. Il timeout della lambda è 60s
        ],
    ],
];
