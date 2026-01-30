# Package Lambda Functions - Simple Version
$ErrorActionPreference = "Stop"

$lambdas = @(
    "reply-strategy-fn",
    "generate-response-fn",
    "text-to-speech-fn",
    "get-file-contents-fn",
    "session-manager-fn",
    "topic-analyzer-fn",
    "context-evaluator-fn"
)

$bucket = "sidea-ai-clone-cfn-deploy-euc1"
$region = "eu-central-1"
$profile = "sirio"

Write-Host "Starting Lambda packaging..."
Write-Host "Bucket: $bucket"
Write-Host "Region: $region"
Write-Host ""

# Create dist directory
New-Item -ItemType Directory -Path "dist" -Force | Out-Null

# Package each Lambda
foreach ($lambda in $lambdas) {
    Write-Host "Packaging $lambda..."

    Push-Location "lambdas\$lambda"

    # Install dependencies
    try {
        composer install --no-dev --optimize-autoloader --quiet 2>&1 | Out-Null
        Write-Host "  Composer OK"
    } catch {
        Write-Host "  Composer skipped"
    }

    # Create ZIP
    $zipPath = "..\..\dist\$lambda.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath
    }

    Compress-Archive -Path ".\*" -DestinationPath $zipPath -Force
    Write-Host "  ZIP created"

    # Upload
    aws s3 cp $zipPath "s3://$bucket/lambdas/$lambda.zip" --region $region --profile $profile --quiet
    Write-Host "  Uploaded to S3"
    Write-Host ""

    Pop-Location
}

# Upload templates
Write-Host "Uploading CloudFormation templates..."
aws s3 sync cloudformation\ "s3://$bucket/cloudformation/" --region $region --profile $profile --exclude "README.md" --quiet

Write-Host "Uploading Step Function definition..."
aws s3 cp step-function-definition-euc1.json "s3://$bucket/" --region $region --profile $profile --quiet

Write-Host ""
Write-Host "Done! All files uploaded to s3://$bucket"
