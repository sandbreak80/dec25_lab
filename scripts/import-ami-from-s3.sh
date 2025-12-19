#!/bin/bash
# Import AMI from S3 (Skip Upload Step)
# Use this when the AMI file is already in S3

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
BUCKET_NAME="appdynamics-lab-resources"
AWS_REGION="us-west-2"
ADMIN_PROFILE="bstoner"
AMI_FILENAME="appd_va_25.7.0.2255.ami"
AMI_NAME="AppD-VA-25.7.0.2255"

# Function to run AWS commands with admin profile
aws_admin() {
    AWS_PROFILE="$ADMIN_PROFILE" aws "$@" --region "$AWS_REGION"
}

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Import AMI from S3                                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "AMI Name: $AMI_NAME"
echo "S3 Location: s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}"
echo "Region: $AWS_REGION"
echo ""

# Verify credentials
log_info "Verifying AWS credentials..."
ADMIN_USER=$(aws_admin sts get-caller-identity --query 'Arn' --output text)
log_success "Authenticated as: $ADMIN_USER"
echo ""

# Wait for IAM policy to propagate
log_info "Waiting 10 seconds for IAM policy propagation..."
sleep 10
echo ""

# ============================================================================
# Import Snapshot from S3
# ============================================================================
log_info "Step 1/2: Importing EBS snapshot from S3..."
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
        echo ""
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
        echo ""
        log_success "Snapshot import completed!"
        
        SNAPSHOT_ID=$(echo "$TASK_INFO" | grep -o '"SnapshotId": *"[^"]*"' | cut -d'"' -f4)
        log_success "Snapshot ID: $SNAPSHOT_ID"
        
        # Save snapshot ID
        mkdir -p "${SCRIPT_DIR}/../state/shared"
        echo "$SNAPSHOT_ID" > "${SCRIPT_DIR}/../state/shared/snapshot.id"
        break
    elif [ "$STATUS" == "deleted" ] || [ "$STATUS" == "deleting" ] || [ "$STATUS" == "failed" ]; then
        if [ $DOTS -gt 0 ]; then echo ""; fi
        echo ""
        log_error "Snapshot import failed with status: $STATUS"
        log_error "Message: $STATUS_MSG"
        exit 1
    fi
done
echo ""

# ============================================================================
# Register Snapshot as AMI
# ============================================================================
log_info "Step 2/2: Registering AMI from snapshot..."
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
echo "Configuration Updated:"
echo "  config/global.cfg (APPD_AMI_ID)"
echo ""
echo "History Logged:"
echo "  logs/ami-import-history.log"
echo ""
log_info "To verify the AMI:"
echo "  aws ec2 describe-images --image-ids $NEW_AMI_ID --region $AWS_REGION --profile $ADMIN_PROFILE"
echo ""
log_info "All deployment scripts will automatically use: $NEW_AMI_ID"
echo ""
log_success "Import process complete!"
echo ""

