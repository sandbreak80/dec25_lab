#!/bin/bash
# Upload and Import AppDynamics Virtual Appliance AMI
# This script handles the complete process of uploading an AMI file and importing it to AWS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Upload & Import AppDynamics Virtual Appliance AMI     ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 [OPTIONS]

Options:
    --ami-file PATH        Path to AMI file (required)
    --ami-name NAME        Name for the AMI (default: from filename)
    --bucket NAME          S3 bucket name (default: appdynamics-lab-resources)
    --region REGION        AWS region (default: us-west-2)
    --admin-profile NAME   AWS profile with admin access (default: default)
    --skip-upload          Skip upload if file already in S3
    --help, -h             Show this help

Example:
    $0 --ami-file ~/Downloads/appd_va_25.7.0.2255.ami
    $0 --ami-file /path/to/ami --ami-name "AppD-VA-25.7.0"

This script will:
  1. Upload AMI file to S3
  2. Create/verify vmimport IAM role
  3. Import snapshot from S3
  4. Register snapshot as AMI
  5. Update state files with new AMI ID
  6. Clean up temporary files

Process takes 20-45 minutes depending on AMI size.

EOF
    exit 1
}

# Default values
BUCKET_NAME="appdynamics-lab-resources"
AWS_REGION="us-west-2"
ADMIN_PROFILE="default"
SKIP_UPLOAD=false
AMI_FILE=""
AMI_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ami-file) AMI_FILE="$2"; shift 2 ;;
        --ami-name) AMI_NAME="$2"; shift 2 ;;
        --bucket) BUCKET_NAME="$2"; shift 2 ;;
        --region) AWS_REGION="$2"; shift 2 ;;
        --admin-profile) ADMIN_PROFILE="$2"; shift 2 ;;
        --skip-upload) SKIP_UPLOAD=true; shift ;;
        --help|-h) show_usage ;;
        *) log_error "Unknown parameter: $1"; show_usage ;;
    esac
done

# Validate required parameters
if [ -z "$AMI_FILE" ]; then
    log_error "AMI file path is required"
    show_usage
fi

if [ ! -f "$AMI_FILE" ]; then
    log_error "AMI file not found: $AMI_FILE"
    exit 1
fi

# Extract filename and determine AMI name
AMI_FILENAME=$(basename "$AMI_FILE")
if [ -z "$AMI_NAME" ]; then
    # Extract version from filename (e.g., appd_va_25.7.0.2255.ami -> AppD-VA-25.7.0.2255)
    AMI_NAME="AppD-VA-$(echo $AMI_FILENAME | sed 's/appd_va_//' | sed 's/.ami$//')"
fi

# Function to run AWS commands with admin profile
aws_admin() {
    AWS_PROFILE="$ADMIN_PROFILE" aws "$@" --region "$AWS_REGION"
}

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  AppDynamics Virtual Appliance AMI Import               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "AMI File: $AMI_FILE"
echo "AMI Name: $AMI_NAME"
echo "Bucket: $BUCKET_NAME"
echo "Region: $AWS_REGION"
echo "Profile: $ADMIN_PROFILE"
echo ""
log_warning "This process takes 20-45 minutes. Do not interrupt!"
echo ""

# Verify admin profile exists and has permissions
log_info "Verifying AWS credentials..."
ADMIN_USER=$(aws_admin sts get-caller-identity --query 'Arn' --output text 2>&1)
if [ $? -ne 0 ]; then
    log_error "Failed to authenticate with profile: $ADMIN_PROFILE"
    log_info "Make sure you have configured this profile in ~/.aws/credentials"
    exit 1
fi
log_success "Authenticated as: $ADMIN_USER"
echo ""

# Get file size for progress tracking
FILE_SIZE=$(du -h "$AMI_FILE" | cut -f1)
log_info "AMI file size: $FILE_SIZE"
echo ""

# ============================================================================
# STEP 1: Upload AMI file to S3
# ============================================================================
if [ "$SKIP_UPLOAD" = true ]; then
    log_info "Skipping upload (--skip-upload specified)"
    log_info "Checking if file exists in S3..."
    if aws_admin s3 ls "s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}" &>/dev/null; then
        log_success "File exists in S3"
    else
        log_error "File not found in S3. Remove --skip-upload to upload it."
        exit 1
    fi
else
    log_info "Step 1/4: Uploading AMI file to S3..."
    echo ""
    
    # Check if bucket exists
    if ! aws_admin s3 ls "s3://${BUCKET_NAME}" &>/dev/null; then
        log_info "Creating S3 bucket: s3://${BUCKET_NAME}"
        if [[ "$AWS_REGION" == "us-east-1" ]]; then
            aws_admin s3api create-bucket --bucket "${BUCKET_NAME}"
        else
            aws_admin s3api create-bucket \
                --bucket "${BUCKET_NAME}" \
                --create-bucket-configuration LocationConstraint="${AWS_REGION}"
        fi
        log_success "Bucket created"
    fi
    
    # Upload with progress
    log_info "Uploading $FILE_SIZE to s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}"
    log_info "This will take several minutes..."
    echo ""
    
    aws_admin s3 cp "$AMI_FILE" "s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}" \
        --storage-class STANDARD \
        --metadata "uploaded=$(date -u +%Y-%m-%dT%H:%M:%SZ),original-name=${AMI_FILENAME}"
    
    if [ $? -eq 0 ]; then
        log_success "Upload completed!"
        UPLOADED_SIZE=$(aws_admin s3 ls "s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}" --human-readable | awk '{print $3" "$4}')
        log_info "S3 file size: $UPLOADED_SIZE"
    else
        log_error "Upload failed"
        exit 1
    fi
fi
echo ""

# ============================================================================
# STEP 2: Create/Verify vmimport IAM Role
# ============================================================================
log_info "Step 2/4: Setting up vmimport IAM role..."
echo ""

# Create trust policy
TRUST_POLICY=$(cat <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals": {
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
EOF
)

# Check if role exists
if aws_admin iam get-role --role-name vmimport &>/dev/null; then
    log_success "vmimport role already exists"
else
    log_info "Creating vmimport IAM role..."
    echo "$TRUST_POLICY" > /tmp/vmimport-trust-policy.json
    aws_admin iam create-role \
        --role-name vmimport \
        --assume-role-policy-document file:///tmp/vmimport-trust-policy.json \
        --description "Role for VM Import/Export service"
    rm /tmp/vmimport-trust-policy.json
    log_success "vmimport role created"
fi

# Create/update role policy
ROLE_POLICY=$(cat <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket"
         ],
         "Resource": [
            "arn:aws:s3:::${BUCKET_NAME}",
            "arn:aws:s3:::${BUCKET_NAME}/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource": "*"
      }
   ]
}
EOF
)

log_info "Attaching policy to vmimport role..."
echo "$ROLE_POLICY" > /tmp/vmimport-role-policy.json
aws_admin iam put-role-policy \
    --role-name vmimport \
    --policy-name vmimport \
    --policy-document file:///tmp/vmimport-role-policy.json
rm /tmp/vmimport-role-policy.json

log_success "IAM role configured"
echo ""

# ============================================================================
# STEP 3: Import Snapshot from S3
# ============================================================================
log_info "Step 3/4: Importing EBS snapshot from S3..."
echo ""

S3_URL="s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}"
log_info "Starting snapshot import from: $S3_URL"

IMPORT_TASK_ID=$(aws_admin ec2 import-snapshot \
    --description "AppDynamics VA - ${AMI_NAME}" \
    --disk-container "Description=${AMI_NAME},Format=RAW,Url=${S3_URL}" \
    --query "ImportTaskId" \
    --output text)

if [ -z "$IMPORT_TASK_ID" ] || [ "$IMPORT_TASK_ID" == "None" ]; then
    log_error "Failed to start import task"
    exit 1
fi

log_success "Import task started: $IMPORT_TASK_ID"
log_info "This process typically takes 20-30 minutes..."
echo ""

# Wait for import to complete
SNAPSHOT_ID=""
LAST_PROGRESS=""
DOTS=0

while true; do
    sleep 30
    
    # Get current status
    TASK_INFO=$(aws_admin ec2 describe-import-snapshot-tasks \
        --import-task-ids "$IMPORT_TASK_ID" \
        --query "ImportSnapshotTasks[0].SnapshotTaskDetail" \
        --output json 2>/dev/null)
    
    if [ -z "$TASK_INFO" ]; then
        log_error "Failed to get task status"
        exit 1
    fi
    
    STATUS=$(echo "$TASK_INFO" | grep -o '"Status": *"[^"]*"' | cut -d'"' -f4)
    PROGRESS=$(echo "$TASK_INFO" | grep -o '"Progress": *"[^"]*"' | cut -d'"' -f4 || echo "0")
    STATUS_MSG=$(echo "$TASK_INFO" | grep -o '"StatusMessage": *"[^"]*"' | cut -d'"' -f4 || echo "")
    
    # Show progress if it changed
    if [ "$PROGRESS" != "$LAST_PROGRESS" ]; then
        log_info "Import progress: ${PROGRESS}% - ${STATUS_MSG}"
        LAST_PROGRESS="$PROGRESS"
        DOTS=0
    else
        # Show dots to indicate we're still checking
        printf "."
        DOTS=$((DOTS + 1))
        if [ $DOTS -ge 60 ]; then
            echo ""
            DOTS=0
        fi
    fi
    
    # Check if completed
    if [ "$STATUS" == "completed" ]; then
        if [ $DOTS -gt 0 ]; then echo ""; fi
        log_success "Snapshot import completed!"
        
        SNAPSHOT_ID=$(echo "$TASK_INFO" | grep -o '"SnapshotId": *"[^"]*"' | cut -d'"' -f4)
        log_success "Snapshot ID: $SNAPSHOT_ID"
        
        # Save snapshot ID
        mkdir -p "${SCRIPT_DIR}/../state/shared"
        echo "$SNAPSHOT_ID" > "${SCRIPT_DIR}/../state/shared/snapshot.id"
        break
    elif [ "$STATUS" == "deleted" ] || [ "$STATUS" == "deleting" ] || [ "$STATUS" == "failed" ]; then
        if [ $DOTS -gt 0 ]; then echo ""; fi
        log_error "Snapshot import failed with status: $STATUS"
        log_error "Message: $STATUS_MSG"
        exit 1
    fi
done
echo ""

# ============================================================================
# STEP 4: Register Snapshot as AMI
# ============================================================================
log_info "Step 4/4: Registering AMI from snapshot..."
echo ""

log_info "Using snapshot: $SNAPSHOT_ID"

NEW_AMI_ID=$(aws_admin ec2 register-image \
    --architecture x86_64 \
    --description "AppDynamics Virtual Appliance - ${AMI_NAME}" \
    --ena-support \
    --sriov-net-support simple \
    --virtualization-type hvm \
    --boot-mode uefi \
    --imds-support v2.0 \
    --name "${AMI_NAME}" \
    --root-device-name /dev/sda1 \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=${SNAPSHOT_ID}}" \
    --query 'ImageId' \
    --output text)

if [ -z "$NEW_AMI_ID" ] || [ "$NEW_AMI_ID" == "None" ]; then
    log_error "Failed to register AMI"
    exit 1
fi

log_success "AMI registered: $NEW_AMI_ID"

# Update global configuration file
log_info "Updating global configuration..."
IMPORT_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Update the APPD_AMI_ID line in global.cfg
if [ -f "${SCRIPT_DIR}/../config/global.cfg" ]; then
    # Backup current config
    cp "${SCRIPT_DIR}/../config/global.cfg" "${SCRIPT_DIR}/../config/global.cfg.backup"
    
    # Update values
    sed -i.tmp "s|^APPD_AMI_ID=.*|APPD_AMI_ID=\"${NEW_AMI_ID}\"|" "${SCRIPT_DIR}/../config/global.cfg"
    sed -i.tmp "s|^APPD_AMI_NAME=.*|APPD_AMI_NAME=\"${AMI_NAME}\"|" "${SCRIPT_DIR}/../config/global.cfg"
    sed -i.tmp "s|^APPD_SNAPSHOT_ID=.*|APPD_SNAPSHOT_ID=\"${SNAPSHOT_ID}\"|" "${SCRIPT_DIR}/../config/global.cfg"
    sed -i.tmp "s|^APPD_AMI_IMPORTED_DATE=.*|APPD_AMI_IMPORTED_DATE=\"${IMPORT_DATE}\"|" "${SCRIPT_DIR}/../config/global.cfg"
    sed -i.tmp "s|^APPD_AMI_SOURCE_FILE=.*|APPD_AMI_SOURCE_FILE=\"${AMI_FILENAME}\"|" "${SCRIPT_DIR}/../config/global.cfg"
    rm "${SCRIPT_DIR}/../config/global.cfg.tmp"
    
    log_success "Global configuration updated: config/global.cfg"
else
    log_error "Global config not found: config/global.cfg"
    exit 1
fi

# Save snapshot ID for reference
mkdir -p "${SCRIPT_DIR}/../state/shared"
echo "$SNAPSHOT_ID" > "${SCRIPT_DIR}/../state/shared/snapshot.id"

# Create import history log
mkdir -p "${SCRIPT_DIR}/../logs"
cat >> "${SCRIPT_DIR}/../logs/ami-import-history.log" << EOF
---
Import Date: ${IMPORT_DATE}
AMI ID: ${NEW_AMI_ID}
AMI Name: ${AMI_NAME}
Snapshot ID: ${SNAPSHOT_ID}
Source File: ${AMI_FILENAME}
S3 Path: s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}
Import Task: ${IMPORT_TASK_ID}
Region: ${AWS_REGION}
---
EOF

log_success "Configuration and history updated"
echo ""

# ============================================================================
# COMPLETION
# ============================================================================
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ AMI Import Complete!                                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "AMI Details:"
echo "  AMI ID: $NEW_AMI_ID"
echo "  Name: $AMI_NAME"
echo "  Region: $AWS_REGION"
echo ""
echo "Snapshot:"
echo "  Snapshot ID: $SNAPSHOT_ID"
echo ""
echo "S3 Location:"
echo "  s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}"
echo ""
echo "Configuration Updated:"
echo "  config/global.cfg (APPD_AMI_ID)"
echo ""
echo "History Logged:"
echo "  logs/ami-import-history.log"
echo ""
log_info "To verify the AMI:"
echo "  aws ec2 describe-images --image-ids $NEW_AMI_ID --region $AWS_REGION"
echo ""
log_info "All deployment scripts will automatically use: $NEW_AMI_ID"
echo ""
log_success "Import process complete!"
echo ""

