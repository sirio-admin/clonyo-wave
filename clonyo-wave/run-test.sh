#!/bin/bash
set -e

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ENDPOINT="http://localhost:4566"
REGION="eu-west-1"
SFN_ARN="arn:aws:states:eu-west-1:000000000000:stateMachine:sidea-ai-clone-prod-wa-message-processor-sfn"

# Verifica argomento
if [ -z "$1" ]; then
    echo -e "${RED}Usage: ./run-test.sh <payload-file>${NC}"
    echo ""
    echo "Examples:"
    echo "  ./run-test.sh test-payloads/text/01-simple-question.json"
    echo "  ./run-test.sh test-payloads/text/02-complex-investment.json"
    echo ""
    echo "Available payloads:"
    echo "  Text messages:"
    ls -1 test-payloads/text/*.json 2>/dev/null | sed 's/^/    /'
    echo "  Audio messages:"
    ls -1 test-payloads/audio/*.json 2>/dev/null | sed 's/^/    /'
    exit 1
fi

PAYLOAD_FILE="$1"

# Verifica file esiste
if [ ! -f "$PAYLOAD_FILE" ]; then
    echo -e "${RED}❌ File not found: $PAYLOAD_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}=== Running Step Function Test ===${NC}"
echo -e "Payload: ${YELLOW}$PAYLOAD_FILE${NC}"
echo ""

# Verifica LocalStack
echo -e "${YELLOW}Checking LocalStack...${NC}"
if ! curl -s $ENDPOINT/_localstack/health > /dev/null; then
    echo -e "${RED}❌ LocalStack not running!${NC}"
    echo "Start with: docker-compose -f docker-compose.local.yml up -d"
    exit 1
fi
echo -e "${GREEN}✅ LocalStack is running${NC}"
echo ""

# Avvia esecuzione
echo -e "${YELLOW}Starting execution...${NC}"
EXECUTION_NAME="test-$(basename $PAYLOAD_FILE .json)-$(date +%s)"

EXECUTION_ARN=$(aws stepfunctions start-execution \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --state-machine-arn "$SFN_ARN" \
    --name "$EXECUTION_NAME" \
    --input file://"$PAYLOAD_FILE" \
    --query 'executionArn' \
    --output text 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to start execution${NC}"
    echo "$EXECUTION_ARN"
    exit 1
fi

echo -e "${GREEN}✅ Execution started${NC}"
echo "   ARN: $EXECUTION_ARN"
echo ""

# Monitora esecuzione
echo -e "${YELLOW}Monitoring execution...${NC}"
MAX_WAIT=120  # 2 minuti max
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(aws stepfunctions describe-execution \
        --endpoint-url $ENDPOINT \
        --region $REGION \
        --execution-arn "$EXECUTION_ARN" \
        --query 'status' \
        --output text 2>/dev/null)
    
    if [ "$STATUS" == "SUCCEEDED" ]; then
        echo -e "\n${GREEN}✅ Execution SUCCEEDED!${NC}"
        break
    elif [ "$STATUS" == "FAILED" ]; then
        echo -e "\n${RED}❌ Execution FAILED!${NC}"
        break
    elif [ "$STATUS" == "TIMED_OUT" ]; then
        echo -e "\n${RED}❌ Execution TIMED OUT!${NC}"
        break
    elif [ "$STATUS" == "ABORTED" ]; then
        echo -e "\n${RED}❌ Execution ABORTED!${NC}"
        break
    fi
    
    echo -n "."
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "\n${YELLOW}⚠️  Timeout waiting for execution${NC}"
fi

echo ""

# Mostra dettagli
echo -e "${YELLOW}Execution Details:${NC}"
aws stepfunctions describe-execution \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --execution-arn "$EXECUTION_ARN" \
    --query '{Status: status, StartDate: startDate, StopDate: stopDate, Input: input}' \
    --output json | jq '.'

echo ""

# Se fallito, mostra errore
if [ "$STATUS" == "FAILED" ]; then
    echo -e "${RED}Error Details:${NC}"
    aws stepfunctions describe-execution \
        --endpoint-url $ENDPOINT \
        --region $REGION \
        --execution-arn "$EXECUTION_ARN" \
        --query 'cause' \
        --output text
    echo ""
fi

# Mostra ultimi eventi
echo -e "${YELLOW}Recent Events (last 10):${NC}"
aws stepfunctions get-execution-history \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --execution-arn "$EXECUTION_ARN" \
    --max-results 10 \
    --reverse-order \
    --query 'events[*].[timestamp, type]' \
    --output table

echo ""

# Verifica dati salvati
echo -e "${YELLOW}Checking saved data...${NC}"
MESSAGES=$(aws dynamodb scan \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --table-name sidea-ai-clone-prod-messages-table \
    --filter-expression "contains(pk, :contact)" \
    --expression-attribute-values '{":contact":{"S":"393462454282"}}' \
    --query 'Count' \
    --output text 2>/dev/null || echo "0")
echo "   Messages in DynamoDB: $MESSAGES"

SESSIONS=$(aws dynamodb scan \
    --endpoint-url $ENDPOINT \
    --region $REGION \
    --table-name sidea-ai-clone-prod-sessions-table \
    --filter-expression "wa_contact_id = :contact" \
    --expression-attribute-values '{":contact":{"S":"393462454282"}}' \
    --query 'Count' \
    --output text 2>/dev/null || echo "0")
echo "   Sessions in DynamoDB: $SESSIONS"

echo ""
echo -e "${GREEN}=== Test Complete ===${NC}"
echo ""
echo "View full history:"
echo "  aws stepfunctions get-execution-history \\"
echo "    --endpoint-url $ENDPOINT \\"
echo "    --region $REGION \\"
echo "    --execution-arn \"$EXECUTION_ARN\""
