# CloudFormation Templates - Clonyo Wave Test Environment

## Status Implementazione

### ✅ Completato
- `infrastructure.yaml`: DynamoDB tables (3), S3 bucket, IAM roles
- `lambda-functions.yaml`: 7 Lambda functions complete

### ⚠️ Step Function - Approccio Semplificato

Data la complessità della Step Function definition (450+ righe con Enhancement Plan v3), abbiamo due opzioni:

#### Opzione A: Deploy Manuale Step Function (RACCOMANDATO per MVP)
1. Deploy infrastructure + Lambda via CloudFormation
2. Creare Step Function manualmente via AWS Console o CLI
3. Basarsi su `step-function-definition-local.json` modificato

#### Opzione B: CloudFormation Completo (Richiede più tempo)
1. Convertire manualmente i 450 righe di JSON → YAML CloudFormation
2. Sostituire tutti gli ARN con `!GetAtt` e parameters
3. Mockare step WhatsApp inline

## Deploy Rapido (Opzione A)

```bash
# 1. Deploy infrastructure
aws cloudformation deploy \
  --template-file cloudformation/infrastructure.yaml \
  --stack-name clonyo-wave-test-euc1-infra \
  --parameter-overrides Environment=test-euc1 BedrockKBId=YT2DL1CBQI \
  --capabilities CAPABILITY_NAMED_IAM \
  --region eu-central-1 \
  --profile sirio

# 2. Package e deploy Lambda (vedi scripts/package-lambdas.sh)

# 3. Deploy Lambda functions
aws cloudformation deploy \
  --template-file cloudformation/lambda-functions.yaml \
  --stack-name clonyo-wave-test-euc1-lambda \
  --parameter-overrides ... \
  --capabilities CAPABILITY_NAMED_IAM \
  --region eu-central-1 \
  --profile sirio

# 4. Creare Step Function manualmente o via script dedicato
```

## Next Steps

Se vuoi l'approccio completo CloudFormation (Opzione B), posso:
1. Leggere `step-function-definition-local.json`
2. Creare `step-function.yaml` con tutti i dettagli
3. Creare `main.yaml` nested stack orchestrator

Dimmi quale opzione preferisci per procedere velocemente!
