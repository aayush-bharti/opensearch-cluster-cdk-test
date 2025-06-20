#!/bin/bash

# Upload OpenSearch Artifact to S3 Script
# Usage: ./upload-artifact-to-s3.sh [artifact-file] [bucket-name] [region] [key-prefix]

set -e

# Default values
DEFAULT_ARTIFACT="opensearch-3.0.0.tar.gz"
DEFAULT_BUCKET="opensearch-artifacts-bucket"
DEFAULT_REGION="us-east-1"
DEFAULT_PREFIX="artifacts"

# Parse command line arguments
ARTIFACT_FILE=${1:-$DEFAULT_ARTIFACT}
BUCKET_NAME=${2:-$DEFAULT_BUCKET}
REGION=${3:-$DEFAULT_REGION}
KEY_PREFIX=${4:-$DEFAULT_PREFIX}

echo "=============================================="
echo "OpenSearch Artifact S3 Upload Script"
echo "=============================================="
echo "Artifact file: $ARTIFACT_FILE"
echo "S3 bucket: $BUCKET_NAME"
echo "Region: $REGION"
echo "Key prefix: $KEY_PREFIX"
echo "=============================================="

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed or not in PATH"
    echo "Please install AWS CLI and configure your credentials"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS credentials are not configured"
    echo "Please run 'aws configure' or set AWS environment variables"
    exit 1
fi

# Check if artifact file exists
if [[ ! -f "$ARTIFACT_FILE" ]]; then
    echo "ERROR: Artifact file '$ARTIFACT_FILE' not found"
    echo ""
    echo "Usage examples:"
    echo "  $0                                                           # Uses defaults"
    echo "  $0 opensearch-3.0.0.tar.gz                                 # Custom artifact"
    echo "  $0 opensearch-3.0.0.tar.gz my-bucket                       # Custom artifact & bucket"
    echo "  $0 opensearch-3.0.0.tar.gz my-bucket us-west-2             # Custom artifact, bucket & region"
    echo "  $0 opensearch-3.0.0.tar.gz my-bucket us-west-2 builds      # All custom parameters"
    exit 1
fi

# Extract filename for S3 key
FILENAME=$(basename "$ARTIFACT_FILE")
S3_KEY="$KEY_PREFIX/$FILENAME"

echo "Creating S3 bucket if it doesn't exist..."
if aws s3 ls "s3://$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
    echo "✓ Bucket '$BUCKET_NAME' already exists"
else
    echo "Creating bucket '$BUCKET_NAME' in region '$REGION'..."
    if [[ "$REGION" == "us-east-1" ]]; then
        # us-east-1 doesn't require location constraint
        aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
    else
        aws s3 mb "s3://$BUCKET_NAME" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo "✓ Bucket created successfully"
fi

echo ""
echo "Uploading artifact to S3..."
aws s3 cp "$ARTIFACT_FILE" "s3://$BUCKET_NAME/$S3_KEY" --region "$REGION"

echo ""
echo "=============================================="
echo "✓ Upload completed successfully!"
echo "=============================================="
echo ""
echo "S3 URI (for CDK deployment):"
echo "  s3://$BUCKET_NAME/$S3_KEY"
echo ""
echo "HTTPS URL (alternative):"
echo "  https://$BUCKET_NAME.s3.$REGION.amazonaws.com/$S3_KEY"
echo ""
echo "CDK Deployment Commands:"
echo ""
echo "# Using S3 URI (recommended - uses IAM for authentication):"
echo "npm run cdk deploy -- --context distributionUrl=\"s3://$BUCKET_NAME/$S3_KEY\""
echo ""
echo "# Using HTTPS URL (requires public bucket access):"
echo "npm run cdk deploy -- --context distributionUrl=\"https://$BUCKET_NAME.s3.$REGION.amazonaws.com/$S3_KEY\""
echo ""
echo "==============================================" 