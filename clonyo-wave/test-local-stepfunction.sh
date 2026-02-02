#!/bin/bash
set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ENDPOINT="http://localhost:4566"
REGION="eu-west-1"

echo -e "${GREEN}=== Test Step Function v2 su LocalStack ===${NC}\n"

# 1. Verifica LocalStack attivo
echo -e "${YELLOW}1. Verificando LocalStack...${NC}"
if ! curl -s $ENDPOINT/_localstack/health > /dev/null; then
    echo -e "${RED}❌ LocalStack non è attivo!${NC}"
    echo "Avvia con: docker-compose -f docker-compose.local.yml up -d"
    exit 1
fi
echo -e "${GREEN}✅ LocalStack attivo${NC}\n"

# 2. Verifica tabelle DynamoDB
echo -e "${YELLOW}2. Verificando tabelle DynamoDB...${NC}"
TABLES=$(aws dynamodb list-tables --endpoint-url $ENDPOINT --region $REGION --output text --query 'TableNames')
if [[ $TABLES == *"sidea-ai-clone-prod-messages-table"* ]]; then
    echo -e "${GREEN}✅ messages-table presente${NC}"
else
    echo -e "${RED}❌ messages-table mancante${NC}"
fi
if [[ $TABLES == *"sidea-ai-clone-prod-sessions-table"* ]]; then
    echo -e "${GREEN}✅ sessions-table presente${NC}"
else
    echo -e "${RED}❌ sessions-table mancante${NC}"
fi
echo ""

# 3. Verifica Step Function
echo -e "${YELLOW}3. Verificando Step Function...${NC}"
SFN_ARN=$(aws stepfunctions list-state-machines \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --query 'stateMachines[?name==`sidea-ai-clone-prod-wa-message-processor-sfn`].stateMachineArn' \
    --output text)

if [ -z "$SFN_ARN" ]; then
    echo -e "${RED}❌ Step Function non trovata!${NC}"
    echo "Ricrea con: docker-compose -f docker-compose.local.yml restart"
    exit 1
fi
echo -e "${GREEN}✅ Step Function trovata${NC}"
echo "   ARN: $SFN_ARN"
echo ""

# 4. Prepara input di test
echo -e "${YELLOW}4. Preparando input di test...${NC}"
TEST_INPUT='{
  "wa_contact": {
    "wa_id": "393462454282",
    "profile": {
      "name": "Mario Rossi"
    }
  },
  "message_ts": 1738162800,
  "reply_to_wa_id": "393462454282",
  "config": {
    "wa_phone_number_arn": "arn:aws:test:eu-west-1:000000000000:phone/test",
    "response_generator": {
      "kb_id": "test-kb-123",
      "temperature": 0.5,
      "max_tokens": 4096
    },
    "text_to_speech": {
      "provider": "elevenlabs",
      "voice_id": "test-voice"
    }
  },
  "text": {
    "body": "Ciao, come funzionano gli ETF?"
  }
}'
echo -e "${GREEN}✅ Input preparato${NC}\n"

# 5. Avvia esecuzione
echo -e "${YELLOW}5. Avviando esecuzione Step Function...${NC}"
EXECUTION_NAME="test-$(date +%s)"
EXECUTION_ARN=$(aws stepfunctions start-execution \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --state-machine-arn "$SFN_ARN" \
    --name "$EXECUTION_NAME" \
    --input "$TEST_INPUT" \
    --query 'executionArn' \
    --output text)

echo -e "${GREEN}✅ Esecuzione avviata${NC}"
echo "   Execution ARN: $EXECUTION_ARN"
echo ""

# 6. Attendi completamento (max 30 secondi)
echo -e "${YELLOW}6. Attendendo completamento...${NC}"
MAX_WAIT=30
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(aws stepfunctions describe-execution \
        --endpoint-url $ENDPOINT \
        --region $REGION \
        --execution-arn "$EXECUTION_ARN" \
        --query 'status' \
        --output text)
    
    if [ "$STATUS" == "SUCCEEDED" ]; then
        echo -e "${GREEN}✅ Esecuzione completata con successo!${NC}\n"
        break
    elif [ "$STATUS" == "FAILED" ]; then
        echo -e "${RED}❌ Esecuzione fallita!${NC}\n"
        break
    elif [ "$STATUS" == "TIMED_OUT" ]; then
        echo -e "${RED}❌ Esecuzione timeout!${NC}\n"
        break
    elif [ "$STATUS" == "ABORTED" ]; then
        echo -e "${RED}❌ Esecuzione abortita!${NC}\n"
        break
    fi
    
    echo -n "."
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done
echo ""

# 7. Mostra dettagli esecuzione
echo -e "${YELLOW}7. Dettagli esecuzione:${NC}"
aws stepfunctions describe-execution \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --execution-arn "$EXECUTION_ARN" \
    --query '{Status: status, StartDate: startDate, StopDate: stopDate}' \
    --output table

echo ""

# 8. Mostra history (ultimi 10 eventi)
echo -e "${YELLOW}8. History (ultimi 10 eventi):${NC}"
aws stepfunctions get-execution-history \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --execution-arn "$EXECUTION_ARN" \
    --max-results 10 \
    --reverse-order \
    --query 'events[*].[timestamp, type, id]' \
    --output table

echo ""

# 9. Verifica dati in DynamoDB
echo -e "${YELLOW}9. Verificando dati salvati in DynamoDB...${NC}"
MESSAGES=$(aws dynamodb scan \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --table-name sidea-ai-clone-prod-messages-table \
    --limit 5 \
    --query 'Count' \
    --output text)
echo "   Messaggi in DynamoDB: $MESSAGES"

SESSIONS=$(aws dynamodb scan \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --table-name sidea-ai-clone-prod-sessions-table \
    --limit 5 \
    --query 'Count' \
    --output text)
echo "   Sessioni in DynamoDB: $SESSIONS"
echo ""

# 10. Riepilogo
echo -e "${GREEN}=== Test Completato ===${NC}"
echo ""
echo "Per vedere l'execution history completa:"
echo "  aws stepfunctions get-execution-history \\"
echo "    --endpoint-url $ENDPOINT \\"
echo "    --region $REGION \\"
echo "    --execution-arn \"$EXECUTION_ARN\""
echo ""
echo "Per vedere i dati in DynamoDB:"
echo "  aws dynamodb scan \\"
echo "    --endpoint-url $ENDPOINT \\"
echo "    --region $REGION \\"
echo "    --table-name sidea-ai-clone-prod-messages-table"
