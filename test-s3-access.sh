#!/bin/bash

# Test S3 Access Script
# This script helps verify AWS CLI configuration and tests S3 access
# similar to what EC2 instances will do when downloading artifacts

set -e

# Default test values
DEFAULT_BUCKET="opensearch-artifacts-bucket"
DEFAULT_REGION="us-east-1"
DEFAULT_KEY="artifacts/opensearch-3.0.0.tar.gz"

# Parse command line arguments
BUCKET_NAME=${1:-$DEFAULT_BUCKET}
REGION=${2:-$DEFAULT_REGION}
TEST_KEY=${3:-$DEFAULT_KEY}

echo "=============================================="
echo "S3 Access Test Script"
echo "=============================================="
echo "Testing S3 access configuration..."
echo "Bucket: $BUCKET_NAME"
echo "Region: $REGION"
echo "Test key: $TEST_KEY"
echo "=============================================="

# Check if AWS CLI is installed
echo "1. Checking AWS CLI installation..."
if ! command -v aws &> /dev/null; then
    echo "❌ ERROR: AWS CLI is not installed or not in PATH"
    echo "   Please install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
else
    echo "✓ AWS CLI is installed"
    aws --version
fi

echo ""

# Check AWS credentials
echo "2. Checking AWS credentials..."
if ! aws sts get-caller-identity 2>/dev/null; then
    echo "❌ ERROR: AWS credentials are not configured"
    echo "   Please configure credentials using one of these methods:"
    echo "   - Run 'aws configure'"
    echo "   - Set AWS environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
    echo "   - Use IAM roles (if running on EC2)"
    exit 1
else
    echo "✓ AWS credentials are configured"
    echo "Account ID: $(aws sts get-caller-identity --query Account --output text)"
    echo "User/Role: $(aws sts get-caller-identity --query Arn --output text)"
fi

echo ""

# Check if bucket exists and is accessible
echo "3. Checking S3 bucket access..."
if aws s3 ls "s3://$BUCKET_NAME" --region "$REGION" &>/dev/null; then
    echo "✓ Bucket '$BUCKET_NAME' exists and is accessible"
    echo "Bucket contents:"
    aws s3 ls "s3://$BUCKET_NAME" --region "$REGION" --recursive | head -10
else
    echo "❌ Cannot access bucket '$BUCKET_NAME'"
    echo "   This could be due to:"
    echo "   - Bucket doesn't exist"
    echo "   - Insufficient permissions"
    echo "   - Incorrect region"
    echo ""
    echo "Available buckets in your account:"
    aws s3 ls 2>/dev/null || echo "   No buckets accessible or list permission denied"
    exit 1
fi

echo ""

# Test downloading the specific artifact if it exists
echo "4. Testing artifact download..."
S3_URI="s3://$BUCKET_NAME/$TEST_KEY"
HTTPS_URL="https://$BUCKET_NAME.s3.$REGION.amazonaws.com/$TEST_KEY"

if aws s3 ls "$S3_URI" --region "$REGION" &>/dev/null; then
    echo "✓ Artifact exists: $S3_URI"
    
    # Test S3 download (what EC2 will do)
    echo "Testing S3 download command (what EC2 instances will run):"
    echo "aws s3 cp \"$S3_URI\" test-download.tar.gz"
    
    if aws s3 cp "$S3_URI" test-download.tar.gz --region "$REGION"; then
        echo "✓ S3 download successful"
        ls -lh test-download.tar.gz
        rm -f test-download.tar.gz
    else
        echo "❌ S3 download failed"
        exit 1
    fi
    
    echo ""
    
    # Test HTTPS download (alternative method)
    echo "Testing HTTPS download (alternative method):"
    echo "curl -L \"$HTTPS_URL\" -o test-https-download.tar.gz"
    
    if curl -L "$HTTPS_URL" -o test-https-download.tar.gz --fail --silent; then
        echo "✓ HTTPS download successful"
        ls -lh test-https-download.tar.gz
        rm -f test-https-download.tar.gz
    else
        echo "❌ HTTPS download failed (this is expected if bucket is private)"
        echo "   Private buckets require S3 URI access with proper IAM permissions"
        rm -f test-https-download.tar.gz
    fi
    
else
    echo "⚠️  Artifact not found: $S3_URI"
    echo "   Available artifacts in bucket:"
    aws s3 ls "s3://$BUCKET_NAME/" --region "$REGION" --recursive | grep -E '\.(tar\.gz|zip)$' || echo "   No .tar.gz or .zip files found"
fi

echo ""

# Show what commands will run on EC2
echo "=============================================="
echo "EC2 Instance Commands Preview"
echo "=============================================="
echo "When your EC2 instances start, they will run commands similar to:"
echo ""
echo "# For S3 URI:"
echo "if [[ \"$S3_URI\" == s3://* ]]; then"
echo "  aws s3 cp \"$S3_URI\" opensearch.tar.gz"
echo "else"
echo "  curl -L \"$S3_URI\" -o opensearch.tar.gz"
echo "fi"
echo ""
echo "# Extract and set permissions:"
echo "tar zxf opensearch.tar.gz -C opensearch --strip-components=1"
echo "chown -R ec2-user:ec2-user opensearch"
echo ""

# Check IAM permissions
echo "=============================================="
echo "IAM Permissions Check"
echo "=============================================="
echo "Checking if current credentials have required S3 permissions..."

# Test basic S3 permissions
PERMISSIONS_OK=true

echo -n "- s3:ListBucket: "
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" &>/dev/null; then
    echo "✓"
else
    echo "❌"
    PERMISSIONS_OK=false
fi

echo -n "- s3:GetObject: "
if [[ -n "$(aws s3 ls "s3://$BUCKET_NAME/" --region "$REGION" 2>/dev/null | head -1)" ]]; then
    echo "✓"
else
    echo "❌"
    PERMISSIONS_OK=false
fi

if [[ "$PERMISSIONS_OK" == "true" ]]; then
    echo ""
    echo "✅ All basic permissions are working!"
    echo "✅ Your EC2 instances should be able to download S3 artifacts"
else
    echo ""
    echo "❌ Some permissions are missing"
    echo "   Make sure your EC2 instances have the AmazonS3ReadOnlyAccess policy"
    echo "   or create a custom policy with s3:GetObject and s3:ListBucket permissions"
fi

echo ""
echo "=============================================="
echo "Test completed!"
echo "=============================================="

# Usage examples
echo ""
echo "Usage examples:"
echo "  $0                                    # Test with defaults"
echo "  $0 my-bucket                         # Test specific bucket"
echo "  $0 my-bucket us-west-2              # Test bucket in specific region"
echo "  $0 my-bucket us-west-2 artifacts/opensearch-2.11.0.tar.gz  # Test specific artifact" 