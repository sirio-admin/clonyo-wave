#!/bin/bash

# ============================================
# Package Lambda Functions for eu-central-1
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Packaging Lambda Functions...${NC}"
echo ""

cd "$(dirname "$0")/.."

LAMBDA_FUNCTIONS=(
    "session-manager-fn"
    "topic-analyzer-fn"
    "context-evaluator-fn"
    "reply-strategy-fn"
    "generate-response-fn"
    "text-to-speech-fn"
    "get-file-contents-fn"
)

for FUNCTION in "${LAMBDA_FUNCTIONS[@]}"; do
    ZIP_FILE="lambdas/${FUNCTION}.zip"
    
    # Check if ZIP already exists
    if [ -f "$ZIP_FILE" ]; then
        echo "✓ ${FUNCTION}.zip already exists (skipping)"
        continue
    fi
    
    echo "Packaging ${FUNCTION}..."
    
    cd "lambdas/${FUNCTION}"
    
    # Check if vendor exists, if not try to install
    if [ ! -d "vendor" ]; then
        echo "  Installing dependencies..."
        if command -v composer &> /dev/null; then
            composer install --no-dev --optimize-autoloader --quiet
        else
            echo "  ⚠ Warning: composer not found and vendor/ missing"
            echo "  Please install dependencies manually: cd lambdas/${FUNCTION} && composer install"
            cd ../..
            continue
        fi
    fi
    
    # Create ZIP
    zip -r "../${FUNCTION}.zip" . \
        -x "*.git*" \
        -x "tests/*" \
        -x "*.env*" \
        -x "phpunit.xml" \
        -x "phpstan.neon" \
        -x "test-events/*" \
        -x "vendor/bin/*" \
        > /dev/null
    
    echo "✓ ${FUNCTION}.zip created"
    
    cd ../..
done

echo ""
echo -e "${GREEN}All Lambda packages ready!${NC}"
echo ""
echo "ZIP files:"
ls -lh lambdas/*.zip
echo ""
