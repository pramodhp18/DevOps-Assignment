#!/bin/bash
set -euo pipefail
REGION="us-east-1"
ACCOUNT_ID="${AWS_ACCOUNT_ID}"
STATE_BUCKET="pgagi-tfstate-${ACCOUNT_ID}"
LOCK_TABLE="pgagi-tfstate-lock"

echo "==> Creating S3 state bucket: $STATE_BUCKET"
aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || echo "Bucket already exists"
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$STATE_BUCKET" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "==> Creating DynamoDB lock table"
aws dynamodb create-table --table-name "$LOCK_TABLE" --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region "$REGION" 2>/dev/null || echo "Table already exists"

echo "==> Creating ECR repositories"
for repo in pgagi-frontend pgagi-backend; do
  aws ecr create-repository --repository-name "$repo" --image-scanning-configuration scanOnPush=true --region "$REGION" 2>/dev/null || echo "Repo $repo already exists"
done
echo "✅ AWS Bootstrap complete! Bucket: $STATE_BUCKET"
