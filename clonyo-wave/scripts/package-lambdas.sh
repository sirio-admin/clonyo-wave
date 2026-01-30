#!/bin/bash
set -e

# Clonyo Wave - Package and Upload Lambda Functions
# This script packages all 7 Lambda functions and uploads them to S3

LAMBDAS=(
  "reply-strategy-fn"
  "generate-response-fn"
  "text-to-speech-fn"
  "get-file-contents-fn"
  "session-manager-fn"
  "topic-analyzer-fn"
  "context-evaluator-fn"
)

BUCKET="sidea-ai-clone-cfn-deploy-euc1"
REGION="eu-central-1"
PROFILE="sirio"

# Safety check
if [ "$AWS_REGION" == "eu-west-1" ]; then
  echo "❌ ERROR: Cannot deploy to eu-west-1 (production region)"
  exit 1
fi

echo "📦 Starting Lambda packaging process..."
echo "Target bucket: s3://$BUCKET"
echo "Region: $REGION"
echo ""

# Create dist directory if not exists
mkdir -p dist

# Check if bucket exists, create if not
if ! aws s3 ls "s3://$BUCKET" --region $REGION --profile $PROFILE 2>/dev/null; then
  echo "Creating S3 bucket: $BUCKET"
  aws s3 mb "s3://$BUCKET" --region $REGION --profile $PROFILE
fi

# Package each Lambda
for lambda in "${LAMBDAS[@]}"; do
  echo "📦 Packaging $lambda..."

  cd "lambdas/$lambda"

  # Install dependencies (production only)
  echo "  → Installing Composer dependencies..."
  composer install --no-dev --optimize-autoloader --quiet 2>/dev/null || {
    echo "  ⚠️  Composer install failed for $lambda, continuing..."
  }

  # Create ZIP
  echo "  → Creating ZIP archive..."
  zip -r "../../dist/$lambda.zip" . \
    -x "*.git*" \
    -x "tests/*" \
    -x "*.md" \
    -x "*config*.json" \
    -x "Taskfile.yml" \
    -q

  ZIP_SIZE=$(du -h "../../dist/$lambda.zip" | cut -f1)
  echo "  → ZIP size: $ZIP_SIZE"

  # Upload to S3
  echo "  → Uploading to S3..."
  aws s3 cp "../../dist/$lambda.zip" "s3://$BUCKET/lambdas/$lambda.zip" \
    --region $REGION \
    --profile $PROFILE \
    --quiet

  echo "  ✅ $lambda packaged and uploaded"
  echo ""

  cd ../..
done

# Upload CloudFormation templates
echo "📤 Uploading CloudFormation templates..."
aws s3 sync cloudformation/ "s3://$BUCKET/cloudformation/" \
  --region $REGION \
  --profile $PROFILE \
  --exclude "README.md" \
  --quiet

# Upload Step Function definition
echo "📤 Uploading Step Function definition..."
aws s3 cp step-function-definition-euc1.json "s3://$BUCKET/step-function-definition-euc1.json" \
  --region $REGION \
  --profile $PROFILE \
  --quiet

echo ""
echo "✅ All packages uploaded to s3://$BUCKET"
echo ""
echo "Next steps:"
echo "  1. Run ./scripts/deploy-infrastructure.sh"
echo "  2. Run ./scripts/deploy-lambdas.sh"
echo "  3. Create Step Function (manually or via script)"
echo "  4. Run ./scripts/test-pipeline.sh"
