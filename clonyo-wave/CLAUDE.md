# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a serverless WhatsApp conversational AI system ("Clonyo-Wave") built on Laravel and deployed to AWS Lambda using Bref. It enables WhatsApp messaging with AI-powered responses and voice cloning capabilities.

**Core Flow:**
1. WhatsApp messages trigger an AWS Step Function workflow (`sidea-ai-clone-prod-wa-message-processor-sfn`)
2. Text messages are processed directly; audio messages are transcribed via Amazon Transcribe
3. AI determines reply strategy (text vs audio) and complexity factor using Claude 3.5 Sonnet
4. Responses are generated using AWS Bedrock with knowledge base retrieval
5. Text-to-speech conversion with ElevenLabs for audio responses
6. Messages stored in DynamoDB with conversation history

## Architecture

### Lambda Functions

Each lambda function is a complete Laravel application in its own directory under `lambdas/`:

- **reply-strategy-fn**: Analyzes user input to determine response mode (text/audio) and complexity factor
  - Handler: `App\Handlers\ReplyStrategyHandler`
  - Service: `App\Services\ReplyStrategyService`
  - Uses Claude 3.5 Sonnet via Bedrock to analyze conversation context

- **generate-response-fn**: Generates AI responses using AWS Bedrock Knowledge Bases
  - Handler: `App\Handlers\GenerateResponseHandler`
  - Service: `App\Services\ResponseGenerator\BedrockService`
  - Retrieves conversation history from DynamoDB

- **text-to-speech-fn**: Converts text responses to audio using ElevenLabs voice cloning
  - Handler: `App\Handlers\TextToSpeechHandler`
  - Service: `App\Services\TextToSpeechConverter\ElevenlabsService`
  - Uploads audio files to S3

- **get-file-contents-fn**: Retrieves transcription results from Amazon Transcribe
  - Handler: `App\Handlers\GetFileContentsHandler`
  - Fetches transcript JSON from S3 URI

### Step Function Workflow

The workflow is defined in `step-function-definition.json` and uses JSONata for transformations:

1. **ExtractVariables**: Extract contact ID, phone ARN, config from input
2. **Store WA message meta**: Update DynamoDB with last message timestamp
3. **Evaluate message type**: Route based on text vs audio
4. **StartTranscriptionJob** (audio path): Transcribe audio with Amazon Transcribe
5. **TransformForResponse**: Normalize input for processing
6. **Store WA received message**: Save user message to DynamoDB
7. **Get reply strategy**: Lambda determines text/audio mode and complexity
8. **Build Knowledge based response**: Lambda generates AI response
9. **Choose output type**: Route to text or audio response
10. **Generate audio from text** (audio path): Lambda converts to speech
11. **Reply to WA User**: Send message via AWS Social Messaging
12. **Store WA sent message**: Save assistant response to DynamoDB

### Data Storage

**DynamoDB Table**: `sidea-ai-clone-prod-messages-table`

Key structure:
- `pk`: `S#{wa_phone_number_arn}#C#{contact_id}` (partition key)
- `sk`: `META` for contact metadata, `M#{timestamp}` for messages (sort key)
- Message attributes: `role` (user/assistant), `type` (text/audio), `content`

**S3 Bucket**: `sidea-ai-clone-prod-wa-media-s3`
- Audio files from users and generated responses

### Project Structure (within each lambda)

```
lambdas/{function-name}/
├── app/
│   ├── Handlers/          # Lambda entry points (implement Bref\Event\Handler)
│   ├── Contracts/         # Interfaces (ResponseGenerator, ReplyStrategy, etc.)
│   ├── Services/          # Business logic implementations
│   ├── Data/              # DTOs using Spatie Laravel Data
│   └── Repositories/      # Data access (DynamoDB, Config)
├── config/
│   └── ai-clone.php       # Configuration for AI services, AWS resources
├── composer.json          # PHP dependencies (Laravel 12, Bref, AWS SDK)
└── .github/
    └── copilot-instructions.md  # Architecture documentation
```

## Development Commands

### Dependencies
```bash
# Install PHP dependencies (in each lambda directory)
cd lambdas/{function-name}
composer install

# Install npm dependencies
npm install
```

### Testing
```bash
# Run all tests with Pest
./vendor/bin/pest

# Run specific test file
./vendor/bin/pest tests/Unit/SomeTest.php

# Run with coverage
./vendor/bin/pest --coverage
```

### Code Quality
```bash
# Auto-fix code style with Laravel Pint
composer fix
# or
./vendor/bin/pint

# Run static analysis with PHPStan
composer stan
# or
./vendor/bin/phpstan analyse --memory-limit=2G
```

### Local Development
```bash
# Start development environment (server, queue, logs, vite)
composer dev

# Clear Laravel config cache
php artisan config:clear
```

## Key Development Patterns

### Handler Pattern
All Lambda functions follow this pattern:
1. Handler class implements `Bref\Event\Handler`
2. Receives event array and Context from AWS
3. Delegates to a service class through dependency injection
4. Returns array response (serialized to JSON)

Example:
```php
class ReplyStrategyHandler implements Handler
{
    public function __construct(
        protected ReplyStrategy $service,
        protected MessagesRepository $messages,
    ) {}

    public function handle(mixed $event, Context $context): array
    {
        return $this->service
            ->withMessages($this->messages->all($event['messages_key']))
            ->analyzeInput($event['userInput']);
    }
}
```

### Configuration
- AWS resources configured via environment variables (see `*-config.json` files)
- Service configuration in `config/ai-clone.php`
- Config retrieved from DynamoDB `sidea-ai-clone-prod-config-table` at runtime

### Data Transfer Objects
Uses Spatie Laravel Data package for type-safe DTOs:
- `MessageData`: Individual message structure
- `ConversationMessageData`: Message with role (user/assistant)
- `ResponseGeneratorData`: Configuration for response generation
- `TextToSpeechData`: Configuration for TTS

### AWS Service Integration
- DynamoDB operations via Laravel's database facade or direct SDK calls
- Bedrock models invoked via `BedrockRuntimeClient`
- S3 operations via Laravel Flysystem with AWS S3 adapter

## Important Considerations

### Reply Strategy Logic
The `ReplyStrategyService` uses sophisticated heuristics to determine text vs audio mode:
- Analyzes conversation context (last 10 messages)
- Considers topic complexity, question type, and emotional sensitivity
- Returns `complexity_factor` (0.0-1.0) and `mode` (text/audio)
- Small talk and info lookups → text
- Technical discussions, personal advice, emotional topics → audio

### Message History
- Conversation messages limited to last 10 for context (see `ReplyStrategyService::withMessages`)
- Messages stored chronologically in DynamoDB using timestamp in sort key
- Both user and assistant messages include content and type metadata

### Deployment Context
- Functions are deployed with Bref PHP 8.4 runtime layer
- Handler specified in Lambda config (e.g., `App\\Handlers\\ReplyStrategyHandler`)
- Environment variables set per-function (see `*-config.json` files)
- Each function has 30-60s timeout and 1024MB memory

### Lambda Configuration Files
The `*-config.json` files at the lambda root contain:
- Handler class path
- Runtime environment variables (table names, ARNs, API keys)
- Timeout and memory settings
- IAM role ARNs

These are reference files showing the deployed configuration, not used for local deployment.
