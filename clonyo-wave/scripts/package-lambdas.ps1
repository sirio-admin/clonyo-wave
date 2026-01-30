# Clonyo Wave - Package and Upload Lambda Functions (PowerShell version)
# This script packages all 7 Lambda functions and uploads them to S3

$ErrorActionPreference = "Stop"

$LAMBDAS = @(
    "reply-strategy-fn",
    "generate-response-fn",
    "text-to-speech-fn",
    "get-file-contents-fn",
    "session-manager-fn",
    "topic-analyzer-fn",
    "context-evaluator-fn"
)

$BUCKET = "sidea-ai-clone-cfn-deploy-euc1"
$REGION = "eu-central-1"
$PROFILE = "sirio"

Write-Host "📦 Starting Lambda packaging process..." -ForegroundColor Green
Write-Host "Target bucket: s3://$BUCKET"
Write-Host "Region: $REGION"
Write-Host ""

# Create dist directory
if (!(Test-Path "dist")) {
    New-Item -ItemType Directory -Path "dist" | Out-Null
}

# Check if bucket exists, create if not
try {
    aws s3 ls "s3://$BUCKET" --region $REGION --profile $PROFILE 2>&1 | Out-Null
} catch {
    Write-Host "Creating S3 bucket: $BUCKET"
    aws s3 mb "s3://$BUCKET" --region $REGION --profile $PROFILE
}

# Package each Lambda
foreach ($lambda in $LAMBDAS) {
    Write-Host "📦 Packaging $lambda..." -ForegroundColor Cyan

    Set-Location "lambdas\$lambda"

    # Install Composer dependencies
    Write-Host "  → Installing Composer dependencies..."
    try {
        composer install --no-dev --optimize-autoloader --quiet 2>&1 | Out-Null
    } catch {
        Write-Host "  ⚠️  Composer install failed for $lambda, continuing..." -ForegroundColor Yellow
    }

    # Create ZIP
    Write-Host "  → Creating ZIP archive..."
    $zipPath = "..\..\dist\$lambda.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    # Compress entire lambda directory (simpler approach)
    Compress-Archive -Path ".\*" -DestinationPath $zipPath -CompressionLevel Optimal -Force

    $zipSize = (Get-Item $zipPath).Length / 1MB
    Write-Host ("  → ZIP size: {0:N2} MB" -f $zipSize)

    # Upload to S3
    Write-Host "  → Uploading to S3..."
    aws s3 cp $zipPath "s3://$BUCKET/lambdas/$lambda.zip" `
        --region $REGION `
        --profile $PROFILE `
        --quiet

    Write-Host "  ✅ $lambda packaged and uploaded" -ForegroundColor Green
    Write-Host ""

    Set-Location ..\..
}

# Upload CloudFormation templates
Write-Host "📤 Uploading CloudFormation templates..." -ForegroundColor Cyan
aws s3 sync cloudformation\ "s3://$BUCKET/cloudformation/" `
    --region $REGION `
    --profile $PROFILE `
    --exclude "README.md" `
    --quiet

# Upload Step Function definition
Write-Host "📤 Uploading Step Function definition..." -ForegroundColor Cyan
aws s3 cp step-function-definition-euc1.json "s3://$BUCKET/step-function-definition-euc1.json" `
    --region $REGION `
    --profile $PROFILE `
    --quiet

Write-Host ""
Write-Host "✅ All packages uploaded to s3://$BUCKET" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run .\scripts\deploy-all.ps1 (or deploy-all.sh in bash)"
Write-Host "  2. Run .\scripts\test-pipeline.ps1 (or test-pipeline.sh in bash)"
