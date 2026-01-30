# Deployment Scripts - Clonyo Wave Test Environment

## Quick Start Guide

### Prerequisites
```bash
# Ensure AWS profile 'sirio' is configured for eu-central-1
aws configure get region --profile sirio  # Should return: eu-central-1
aws sts get-caller-identity --profile sirio  # Verify access

# Make scripts executable
chmod +x scripts/*.sh
```

### Deployment Steps

#### 1. Package Lambda Functions
```bash
./scripts/package-lambdas.sh
```
- Installs Composer dependencies
- Creates ZIP archives for all 7 Lambda functions
- Uploads to S3 bucket `sidea-ai-clone-cfn-deploy-euc1`
- Uploads CloudFormation templates

**Output**: All Lambda ZIPs in `dist/` and uploaded to S3

---

#### 2. Deploy Infrastructure
```bash
./scripts/deploy-infrastructure.sh
```
- Creates DynamoDB tables (messages, sessions, config)
- Creates S3 Media bucket
- Creates IAM roles (Lambda execution, Step Function execution)

**Output**: Stack `clonyo-wave-test-euc1-infra` with all base resources

---

#### 3. Deploy Lambda Functions
```bash
./scripts/deploy-lambdas.sh
```
- Deploys all 7 Lambda functions
- Configures environment variables
- Attaches Bref PHP 8.4 layer
- Links to infrastructure resources

**Output**: Stack `clonyo-wave-test-euc1-lambda` with 7 functions

---

#### 4. Create Step Function (Manual)

**Option A: AWS Console**
1. Go to Step Functions console in eu-central-1
2. Create new state machine
3. Use `step-function-definition-local.json` as template
4. Replace all ARNs with eu-central-1 versions
5. Replace table names with `test-euc1` versions
6. Mock WhatsApp steps (replace with Pass states)

**Option B: AWS CLI** (TODO: Create automated script)
```bash
# TODO: ./scripts/create-step-function.sh
```

---

#### 5. Test Pipeline (After Step Function Created)
```bash
# TODO: Create test script once Step Function ARN is known
# ./scripts/test-pipeline.sh
```

---

### Cleanup

#### Destroy Entire Environment
```bash
./scripts/destroy-euc1.sh
```
⚠️ **WARNING**: This deletes EVERYTHING in test environment!
- Deletes both CloudFormation stacks
- Empties and deletes S3 buckets
- Removes all Lambda functions, DynamoDB tables, IAM roles

---

## Scripts Reference

| Script | Purpose | Duration | Safe to Rerun |
|--------|---------|----------|---------------|
| `package-lambdas.sh` | Package & upload Lambda ZIPs | ~2-3 min | ✅ Yes |
| `deploy-infrastructure.sh` | Deploy DynamoDB, S3, IAM | ~3-5 min | ✅ Yes (idempotent) |
| `deploy-lambdas.sh` | Deploy 7 Lambda functions | ~2-3 min | ✅ Yes (idempotent) |
| `destroy-euc1.sh` | Destroy entire environment | ~5-10 min | ⚠️ Use with caution |

---

## Troubleshooting

### Issue: Composer install fails
```bash
# Install Composer globally first
# Or use Docker:
docker run --rm -v $(pwd):/app composer install --no-dev
```

### Issue: S3 bucket already exists
```bash
# Bucket names are global - check if it exists in another region
aws s3 ls s3://sidea-ai-clone-cfn-deploy-euc1
```

### Issue: Stack deployment fails
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name clonyo-wave-test-euc1-infra \
  --region eu-central-1 \
  --profile sirio \
  --max-items 20
```

### Issue: Lambda functions not working
```bash
# Check CloudWatch Logs
aws logs tail /aws/lambda/sidea-ai-clone-test-euc1-reply-strategy-fn \
  --follow \
  --region eu-central-1 \
  --profile sirio
```

---

## Next Steps After Deployment

1. **Verify Resources**
```bash
# List Lambda functions
aws lambda list-functions \
  --region eu-central-1 \
  --profile sirio \
  --query 'Functions[?contains(FunctionName, `test-euc1`)].FunctionName'

# List DynamoDB tables
aws dynamodb list-tables \
  --region eu-central-1 \
  --profile sirio \
  --query 'TableNames[?contains(@, `test-euc1`)]'
```

2. **Create Step Function** (manual or scripted)

3. **Run Test Execution** with sample payload

4. **Monitor & Debug** via CloudWatch

5. **Iterate** based on test results

---

## Safety Checklist

Before deploying, verify:
- [ ] AWS profile is `sirio`
- [ ] Region is `eu-central-1` (NOT eu-west-1)
- [ ] No production resources will be affected
- [ ] All resource names contain `test-euc1`
- [ ] Have backup/snapshot if needed (for data migration scenarios)

---

## Cost Estimation

Monthly cost for test environment (assuming 100 test executions):
- Lambda invocations: ~$0.10
- DynamoDB (PAY_PER_REQUEST): ~$0.05
- S3 storage: ~$0.05
- Step Functions: ~$0.10
- Bedrock API calls: ~$6.40
- **Total: ~$7/month**

To minimize costs:
- Delete environment when not in use (`destroy-euc1.sh`)
- Recreate when needed (scripts make it easy)
- Use smaller models (Haiku instead of Sonnet where possible)
