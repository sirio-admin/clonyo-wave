#!/bin/bash
set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurazione AWS eu-central-1
REGION="eu-central-1"
PROFILE="sirio"
SFN_NAME="sidea-ai-clone-test-euc1-wa-message-processor-sfn"

# Help
show_help() {
    echo -e "${CYAN}=== Check Step Function Execution ===${NC}"
    echo ""
    echo "Uso: $0 [opzioni] [comando]"
    echo ""
    echo "Comandi:"
    echo "  list                    Lista le ultime esecuzioni (default: 10)"
    echo "  status <execution-arn>  Mostra lo stato di un'esecuzione specifica"
    echo "  history <execution-arn> Mostra la history completa di un'esecuzione"
    echo "  latest                  Mostra i dettagli dell'ultima esecuzione"
    echo "  running                 Lista solo le esecuzioni in corso"
    echo "  failed                  Lista solo le esecuzioni fallite"
    echo ""
    echo "Opzioni:"
    echo "  --region <region>       Specifica la region AWS (default: eu-central-1)"
    echo "  -n <numero>             Numero di risultati da mostrare (default: 10)"
    echo "  -h, --help              Mostra questo help"
    echo ""
    echo "Esempi:"
    echo "  $0 list                           # Lista ultime 10 esecuzioni su AWS"
    echo "  $0 latest                         # Ultima esecuzione"
    echo "  $0 status arn:aws:states:...      # Dettagli di un'esecuzione specifica"
    echo "  $0 history arn:aws:states:...     # History completa"
    echo "  $0 -n 20 list                     # Ultime 20 esecuzioni"
    echo ""
}

# Parse argomenti
LIMIT=10
COMMAND=""
EXECUTION_ARN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            REGION="$2"
            shift 2
            ;;
        -n)
            LIMIT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        list|status|history|latest|running|failed)
            COMMAND="$1"
            shift
            if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                EXECUTION_ARN="$1"
                shift
            fi
            ;;
        arn:*)
            EXECUTION_ARN="$1"
            shift
            ;;
        *)
            echo -e "${RED}Argomento non riconosciuto: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Default command
if [ -z "$COMMAND" ]; then
    COMMAND="list"
fi

# Opzioni AWS CLI
AWS_OPTS="--region $REGION --profile $PROFILE"

# Funzione per ottenere l'ARN della Step Function
get_sfn_arn() {
    aws stepfunctions list-state-machines $AWS_OPTS \
        --query "stateMachines[?name==\`$SFN_NAME\`].stateMachineArn" \
        --output text 2>/dev/null
}

# Mostra ambiente
show_env() {
    echo -e "${BLUE}📍 AWS $REGION${NC}"
}

# Formatta stato con colore
format_status() {
    local status=$1
    case $status in
        RUNNING)
            echo -e "${YELLOW}⏳ RUNNING${NC}"
            ;;
        SUCCEEDED)
            echo -e "${GREEN}✅ SUCCEEDED${NC}"
            ;;
        FAILED)
            echo -e "${RED}❌ FAILED${NC}"
            ;;
        TIMED_OUT)
            echo -e "${RED}⏰ TIMED_OUT${NC}"
            ;;
        ABORTED)
            echo -e "${RED}🛑 ABORTED${NC}"
            ;;
        *)
            echo "$status"
            ;;
    esac
}

# Lista esecuzioni
list_executions() {
    local status_filter="$1"
    local SFN_ARN=$(get_sfn_arn)

    if [ -z "$SFN_ARN" ]; then
        echo -e "${RED}❌ Step Function '$SFN_NAME' non trovata!${NC}"
        exit 1
    fi

    echo -e "${CYAN}=== Esecuzioni Step Function ===${NC}"
    echo -e "State Machine: ${YELLOW}$SFN_NAME${NC}"
    echo ""

    local CMD="aws stepfunctions list-executions $AWS_OPTS --state-machine-arn $SFN_ARN --max-results $LIMIT"

    if [ -n "$status_filter" ]; then
        CMD="$CMD --status-filter $status_filter"
        echo -e "Filtro: ${YELLOW}$status_filter${NC}"
    fi

    local EXECUTIONS=$($CMD --output json)
    local COUNT=$(echo "$EXECUTIONS" | jq '.executions | length')

    if [ "$COUNT" = "0" ]; then
        echo -e "${YELLOW}Nessuna esecuzione trovata${NC}"
        return
    fi

    echo -e "Trovate: ${GREEN}$COUNT${NC} esecuzioni (max $LIMIT)"
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────${NC}"
    printf "%-20s %-12s %-25s %-25s\n" "NOME" "STATO" "INIZIO" "FINE"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────${NC}"

    echo "$EXECUTIONS" | jq -r '.executions[] | [.name, .status, .startDate, .stopDate // "N/A"] | @tsv' | \
    while IFS=$'\t' read -r name status start stop; do
        # Formatta date
        start_fmt=$(echo "$start" | cut -d'.' -f1 | sed 's/T/ /')
        if [ "$stop" != "N/A" ] && [ "$stop" != "null" ]; then
            stop_fmt=$(echo "$stop" | cut -d'.' -f1 | sed 's/T/ /')
        else
            stop_fmt="-"
        fi

        # Colore per stato
        case $status in
            RUNNING)   status_colored="${YELLOW}RUNNING${NC}" ;;
            SUCCEEDED) status_colored="${GREEN}SUCCEEDED${NC}" ;;
            FAILED)    status_colored="${RED}FAILED${NC}" ;;
            TIMED_OUT) status_colored="${RED}TIMED_OUT${NC}" ;;
            ABORTED)   status_colored="${RED}ABORTED${NC}" ;;
            *)         status_colored="$status" ;;
        esac

        printf "%-20s " "$name"
        printf "%-12b " "$status_colored"
        printf "%-25s %-25s\n" "$start_fmt" "$stop_fmt"
    done

    echo ""
}

# Mostra stato esecuzione
show_status() {
    local ARN="$1"

    if [ -z "$ARN" ]; then
        echo -e "${RED}❌ Specificare l'execution ARN${NC}"
        echo "Uso: $0 status <execution-arn>"
        exit 1
    fi

    echo -e "${CYAN}=== Dettagli Esecuzione ===${NC}"
    echo ""

    local EXEC_DETAILS=$(aws stepfunctions describe-execution $AWS_OPTS --execution-arn "$ARN" --output json 2>/dev/null)

    if [ -z "$EXEC_DETAILS" ]; then
        echo -e "${RED}❌ Esecuzione non trovata: $ARN${NC}"
        exit 1
    fi

    local NAME=$(echo "$EXEC_DETAILS" | jq -r '.name')
    local STATUS=$(echo "$EXEC_DETAILS" | jq -r '.status')
    local START=$(echo "$EXEC_DETAILS" | jq -r '.startDate' | cut -d'.' -f1 | sed 's/T/ /')
    local STOP=$(echo "$EXEC_DETAILS" | jq -r '.stopDate // "N/A"')
    local INPUT=$(echo "$EXEC_DETAILS" | jq -r '.input')
    local OUTPUT=$(echo "$EXEC_DETAILS" | jq -r '.output // "N/A"')
    local ERROR=$(echo "$EXEC_DETAILS" | jq -r '.error // empty')
    local CAUSE=$(echo "$EXEC_DETAILS" | jq -r '.cause // empty')

    echo -e "Nome:    ${YELLOW}$NAME${NC}"
    echo -e "Stato:   $(format_status $STATUS)"
    echo -e "Inizio:  $START"
    if [ "$STOP" != "N/A" ] && [ "$STOP" != "null" ]; then
        STOP_FMT=$(echo "$STOP" | cut -d'.' -f1 | sed 's/T/ /')
        echo -e "Fine:    $STOP_FMT"
    fi
    echo ""

    # Se fallita, mostra errore
    if [ -n "$ERROR" ]; then
        echo -e "${RED}=== Errore ===${NC}"
        echo -e "Error: ${RED}$ERROR${NC}"
        if [ -n "$CAUSE" ]; then
            echo -e "Cause: $CAUSE"
        fi
        echo ""
    fi

    # Mostra input (troncato)
    echo -e "${CYAN}=== Input ===${NC}"
    echo "$INPUT" | jq '.' 2>/dev/null || echo "$INPUT"
    echo ""

    # Se completata con successo, mostra output
    if [ "$STATUS" = "SUCCEEDED" ] && [ "$OUTPUT" != "N/A" ] && [ "$OUTPUT" != "null" ]; then
        echo -e "${GREEN}=== Output ===${NC}"
        echo "$OUTPUT" | jq '.' 2>/dev/null || echo "$OUTPUT"
        echo ""
    fi

    # Mostra ultimi eventi
    echo -e "${CYAN}=== Ultimi 5 Eventi ===${NC}"
    aws stepfunctions get-execution-history $AWS_OPTS \
        --execution-arn "$ARN" \
        --max-results 5 \
        --reverse-order \
        --query 'events[*].[id, type, timestamp]' \
        --output table
}

# Mostra history completa
show_history() {
    local ARN="$1"

    if [ -z "$ARN" ]; then
        echo -e "${RED}❌ Specificare l'execution ARN${NC}"
        echo "Uso: $0 history <execution-arn>"
        exit 1
    fi

    echo -e "${CYAN}=== History Completa Esecuzione ===${NC}"
    echo -e "ARN: ${YELLOW}$ARN${NC}"
    echo ""

    aws stepfunctions get-execution-history $AWS_OPTS \
        --execution-arn "$ARN" \
        --output json | jq -r '.events[] | "\(.timestamp | split(".")[0] | gsub("T"; " ")) | \(.type) | \(.id)"' | \
    while IFS='|' read -r ts type id; do
        # Colora per tipo
        case $type in
            *Started*|*Entered*)
                echo -e "${GREEN}$ts${NC} | ${BLUE}$type${NC} | $id"
                ;;
            *Failed*|*TimedOut*|*Aborted*)
                echo -e "${GREEN}$ts${NC} | ${RED}$type${NC} | $id"
                ;;
            *Succeeded*|*Exited*)
                echo -e "${GREEN}$ts${NC} | ${GREEN}$type${NC} | $id"
                ;;
            *)
                echo -e "${GREEN}$ts${NC} | $type | $id"
                ;;
        esac
    done
}

# Mostra ultima esecuzione
show_latest() {
    local SFN_ARN=$(get_sfn_arn)

    if [ -z "$SFN_ARN" ]; then
        echo -e "${RED}❌ Step Function '$SFN_NAME' non trovata!${NC}"
        exit 1
    fi

    local LATEST_ARN=$(aws stepfunctions list-executions $AWS_OPTS \
        --state-machine-arn "$SFN_ARN" \
        --max-results 1 \
        --query 'executions[0].executionArn' \
        --output text)

    if [ -z "$LATEST_ARN" ] || [ "$LATEST_ARN" = "None" ]; then
        echo -e "${YELLOW}Nessuna esecuzione trovata${NC}"
        exit 0
    fi

    show_status "$LATEST_ARN"
}

# Main
show_env
echo ""

case $COMMAND in
    list)
        list_executions
        ;;
    status)
        show_status "$EXECUTION_ARN"
        ;;
    history)
        show_history "$EXECUTION_ARN"
        ;;
    latest)
        show_latest
        ;;
    running)
        list_executions "RUNNING"
        ;;
    failed)
        list_executions "FAILED"
        ;;
    *)
        echo -e "${RED}Comando non riconosciuto: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac
