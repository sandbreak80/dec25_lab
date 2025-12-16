#!/bin/bash
# Upload License File to S3
# This script uploads the license.lic file to S3 for distribution to all labs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Upload AppDynamics License to S3                       ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 [OPTIONS]

Options:
    --bucket NAME          S3 bucket name (default: appdynamics-lab-resources)
    --region REGION        AWS region (default: us-west-2)
    --license-file PATH    Path to license file (default: license.lic)
    --admin-profile NAME   AWS profile with S3 admin access (default: default)
    --help, -h             Show this help

Example:
    $0
    $0 --admin-profile admin
    $0 --bucket my-lab-bucket --license-file /path/to/license.lic

This script will:
  1. Use admin AWS profile for S3 operations
  2. Create S3 bucket if it doesn't exist
  3. Upload license.lic to S3
  4. Set appropriate permissions
  5. Display download URLs for students

AWS Profile Setup:
  Configure both profiles in ~/.aws/config and ~/.aws/credentials:
  
  [default]                    # Your admin profile
  region = us-west-2
  
  [profile lab-student]        # Lab student profile
  region = us-west-2

EOF
    exit 1
}

# Default values
BUCKET_NAME="appdynamics-lab-resources"
AWS_REGION="us-west-2"
LICENSE_FILE="${SCRIPT_DIR}/../license.lic"
ADMIN_PROFILE="default"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --bucket) BUCKET_NAME="$2"; shift 2 ;;
        --region) AWS_REGION="$2"; shift 2 ;;
        --license-file) LICENSE_FILE="$2"; shift 2 ;;
        --admin-profile) ADMIN_PROFILE="$2"; shift 2 ;;
        --help|-h) show_usage ;;
        *) log_error "Unknown parameter: $1"; show_usage ;;
    esac
done

# Function to run AWS commands with admin profile
aws_admin() {
    AWS_PROFILE="$ADMIN_PROFILE" aws "$@"
}

log_info "AppDynamics License Upload to S3"
echo ""
echo "Bucket: $BUCKET_NAME"
echo "Region: $AWS_REGION"
echo "License File: $LICENSE_FILE"
echo "Admin Profile: $ADMIN_PROFILE"
echo ""

# Verify admin profile exists and has permissions
log_info "Verifying admin AWS profile..."
ADMIN_USER=$(aws_admin sts get-caller-identity --query 'Arn' --output text 2>&1)
if [ $? -ne 0 ]; then
    log_error "Failed to authenticate with admin profile: $ADMIN_PROFILE"
    log_info "Make sure you have configured this profile in ~/.aws/credentials"
    exit 1
fi

log_success "Authenticated as: $ADMIN_USER"
echo ""

# Verify license file exists
if [[ ! -f "$LICENSE_FILE" ]]; then
    log_error "License file not found: $LICENSE_FILE"
    exit 1
fi

# Verify license file is valid
if ! grep -q "property_version" "$LICENSE_FILE"; then
    log_error "File does not appear to be a valid AppDynamics license file"
    exit 1
fi

# Extract license expiration for verification
EXPIRY=$(grep "property_expiration_date_iso" "$LICENSE_FILE" | cut -d'=' -f2)
log_info "License expires: $EXPIRY"
echo ""

# Check if bucket exists
log_info "Checking if S3 bucket exists..."
if aws_admin s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
    log_success "Bucket exists: s3://${BUCKET_NAME}"
else
    log_info "Creating S3 bucket: s3://${BUCKET_NAME}"
    
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
        # us-east-1 doesn't use LocationConstraint
        aws_admin s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}"
    else
        aws_admin s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    
    log_success "Bucket created"
fi

# Enable versioning (optional but recommended)
log_info "Enabling bucket versioning..."
aws_admin s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

# Upload license file
log_info "Uploading license file to S3..."
aws_admin s3 cp "$LICENSE_FILE" "s3://${BUCKET_NAME}/shared/license.lic" \
    --metadata "uploaded=$(date -u +%Y-%m-%dT%H:%M:%SZ),expiry=${EXPIRY}" \
    --content-type "text/plain"

log_success "License file uploaded!"
echo ""

# Get file info
FILE_SIZE=$(aws_admin s3 ls "s3://${BUCKET_NAME}/shared/license.lic" | awk '{print $3}')
log_info "File size: $FILE_SIZE bytes"

# Update bucket policy to allow read access from EC2 instances
log_info "Setting bucket policy for lab access..."
cat > /tmp/bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLabStudentRead",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/shared/*"
    },
    {
      "Sid": "AllowLabStudentList",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}",
      "Condition": {
        "StringLike": {
          "s3:prefix": "shared/*"
        }
      }
    }
  ]
}
EOF

# Try to set bucket policy (may fail due to block public access settings)
if aws_admin s3api put-bucket-policy \
    --bucket "${BUCKET_NAME}" \
    --policy file:///tmp/bucket-policy.json 2>&1; then
    log_success "Bucket policy configured"
else
    log_warning "Could not set bucket policy (Block Public Access is enabled)"
    log_info "This is fine - lab-student will use IAM authentication"
fi

rm /tmp/bucket-policy.json

# Ensure block public access is enabled (security best practice)
log_info "Configuring public access block..."
aws_admin s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 2>/dev/null || true

log_success "Access configuration complete"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ License Upload Complete!                             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "S3 Location:"
echo "  s3://${BUCKET_NAME}/shared/license.lic"
echo ""
echo "Download URL (for scripts):"
echo "  https://${BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com/shared/license.lic"
echo ""
echo "Students can download using:"
echo "  aws s3 cp s3://${BUCKET_NAME}/shared/license.lic /tmp/license.lic"
echo ""
echo "Or from VM1:"
echo "  ./scripts/download-license.sh --team <number>"
echo ""

# Save bucket info for deployment scripts
mkdir -p "${SCRIPT_DIR}/../state/shared"
cat > "${SCRIPT_DIR}/../state/shared/license-s3.txt" << EOF
BUCKET_NAME=${BUCKET_NAME}
AWS_REGION=${AWS_REGION}
S3_PATH=s3://${BUCKET_NAME}/shared/license.lic
UPLOAD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EXPIRY=${EXPIRY}
EOF

log_success "Configuration saved to state/shared/license-s3.txt"
echo ""

