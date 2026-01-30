# AI Clone Project Architecture Guide

This document provides essential context for AI agents working with the AI Clone codebase.

## Project Overview

AI Clone is a serverless application that enables WhatsApp conversational AI with voice clone capabilities. It's built on Laravel and deployed to AWS Lambda using Bref.

Key components:
- WhatsApp message routing and processing
- AI response generation using AWS Bedrock
- Text-to-speech with voice cloning using ElevenLabs
- Message and conversation storage in DynamoDB

## Core Architecture

### Message Flow
1. WhatsApp messages arrive via SQS → `wa-message-router-fn`
2. Messages are processed through a Step Function workflow:
   - Text messages go directly to response generation
   - Audio messages are transcribed first
3. Responses are generated using AWS Bedrock (Claude 3 Sonnet)
4. Optional text-to-speech conversion with ElevenLabs

### Project Structure
- `app/Handlers/` - Lambda function entry points
- `app/Contracts/` - Core interfaces (ResponseGenerator, TextToSpeechConverter)
- `app/Services/` - Implementation of core business logic
- `app/Data/` - Data transfer objects and value objects
- `config/ai-clone.php` - Configuration for AI services and AWS resources

## Development Workflows

### Local Development
```bash
# Install dependencies
composer install
npm install

# Run tests
./vendor/bin/pest

# Deploy to AWS
serverless deploy
```

### Key Development Patterns
1. Data classes use Spatie's Laravel Data package
2. AWS services are wrapped in interfaces for testability
3. Configuration is managed through `config/ai-clone.php`
4. DynamoDB keys follow pattern: `S#{wa_phone_number_arn}#C#{contact_id}`

## Infrastructure (Terraform)

The `ai-clone-tf/` directory contains Terraform modules for:
- `wa-message-processor/` - Step Functions, DynamoDB tables, S3 buckets
- `wa-webhooks-router/` - SNS topics, SQS queues for webhook handling

Key resources are organized as reusable modules with standardized interfaces.

## Testing

1. Unit tests in `tests/Unit/`
2. Feature tests in `tests/Feature/`
3. Test events for Lambda functions in `test-events/`

Use `MessageData`, `ConversationMessageData` etc. for structured test data.

## Common Tasks

### Adding New Message Types
1. Update state machine definition in `step-function.tf-tpl.json`
2. Implement handler in `app/Handlers/`
3. Add corresponding service class in `app/Services/`
4. Update DynamoDB schema if needed

### Configuring AI Models
1. Update `config/ai-clone.php` with model parameters
2. Update IAM roles in `serverless.yml` if needed
3. Implement provider-specific logic in service classes