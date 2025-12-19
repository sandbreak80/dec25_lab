#!/bin/bash
# Check AMI Import Status
# Quick script to check the status of ongoing AMI import

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

AWS_REGION="us-west-2"
ADMIN_PROFILE="bstoner"

# Get the most recent import task
IMPORT_TASK_ID=$(AWS_PROFILE="$ADMIN_PROFILE" aws ec2 describe-import-snapshot-tasks \
    --region "$AWS_REGION" \
    --query "ImportSnapshotTasks[0].ImportTaskId" \
    --output text 2>/dev/null)

if [ -z "$IMPORT_TASK_ID" ] || [ "$IMPORT_TASK_ID" == "None" ]; then
    log_error "No import tasks found"
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  AMI Import Status                                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Import Task: $IMPORT_TASK_ID"
echo ""

# Get detailed status
TASK_INFO=$(AWS_PROFILE="$ADMIN_PROFILE" aws ec2 describe-import-snapshot-tasks \
    --import-task-ids "$IMPORT_TASK_ID" \
    --region "$AWS_REGION" \
    --output json)

echo "$TASK_INFO" | python3 -m json.tool 2>/dev/null || echo "$TASK_INFO"

# Extract key info
STATUS=$(echo "$TASK_INFO" | grep -o '"Status": *"[^"]*"' | head -1 | cut -d'"' -f4)
PROGRESS=$(echo "$TASK_INFO" | grep -o '"Progress": *"[^"]*"' | head -1 | cut -d'"' -f4 || echo "N/A")
STATUS_MSG=$(echo "$TASK_INFO" | grep -o '"StatusMessage": *"[^"]*"' | head -1 | cut -d'"' -f4 || echo "N/A")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Current Status: $STATUS"
echo "Progress: $PROGRESS%"
echo "Message: $STATUS_MSG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$STATUS" == "completed" ]; then
    SNAPSHOT_ID=$(echo "$TASK_INFO" | grep -o '"SnapshotId": *"[^"]*"' | head -1 | cut -d'"' -f4)
    log_success "Import complete! Snapshot ID: $SNAPSHOT_ID"
elif [ "$STATUS" == "active" ]; then
    log_info "Import in progress... Check again in a few minutes"
else
    log_warning "Status: $STATUS"
fi

echo ""

