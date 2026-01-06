#!/bin/bash
# Cleanup ALL orphaned 500GB volumes (AppDynamics data volumes)
# This script finds and deletes ALL unattached 500GB volumes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

AWS_REGION="${AWS_REGION:-us-west-2}"

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Cleanup ALL Orphaned 500GB Volumes                    ║
╚══════════════════════════════════════════════════════════╝

This script will DELETE ALL unattached 500GB volumes in your account.
These are likely AppDynamics data volumes left behind from terminated instances.

⚠️  WARNING: This will delete volumes that:
   - Are exactly 500GB in size
   - Are in 'available' state (not attached to any instance)
   - Are in region: ${AWS_REGION}

This action CANNOT be undone!

EOF

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS CLI is not configured or credentials are invalid"
    log_info "Run: aws configure"
    exit 1
fi

log_success "AWS CLI configured"
echo ""

# Get all orphaned 500GB volumes
log_info "Scanning for orphaned 500GB volumes..."
ORPHAN_VOLUMES=$(aws ec2 describe-volumes \
    --filters "Name=size,Values=500" "Name=status,Values=available" \
    --query 'Volumes[*].[VolumeId,Size,State,AvailabilityZone,CreateTime]' \
    --output text \
    --region "${AWS_REGION}" 2>/dev/null)

if [ -z "$ORPHAN_VOLUMES" ]; then
    log_success "No orphaned 500GB volumes found!"
    exit 0
fi

# Count volumes
VOLUME_COUNT=$(echo "$ORPHAN_VOLUMES" | wc -l | tr -d ' ')
TOTAL_SIZE_GB=$((VOLUME_COUNT * 500))
TOTAL_SIZE_TB=$(echo "scale=2; $TOTAL_SIZE_GB / 1024" | bc)

log_warning "Found ${VOLUME_COUNT} orphaned 500GB volumes (${TOTAL_SIZE_TB} TB total)"
echo ""
echo "Sample volumes (first 10):"
echo "$ORPHAN_VOLUMES" | head -10 | awk '{printf "  %-24s  %4s GB  %-12s  %s  %s\n", $1, $2, $3, $4, $5}'

if [ $VOLUME_COUNT -gt 10 ]; then
    echo "  ... and $((VOLUME_COUNT - 10)) more volumes"
fi

echo ""
log_warning "Estimated monthly cost: \$${TOTAL_SIZE_GB}.00 (at \$0.10/GB-month for gp3)"
echo ""

# Final confirmation
read -p "Type 'DELETE ALL VOLUMES' to proceed: " confirmation

if [ "$confirmation" != "DELETE ALL VOLUMES" ]; then
    log_error "Confirmation failed. Exiting."
    exit 1
fi

echo ""
log_info "Starting bulk deletion of ${VOLUME_COUNT} volumes..."
echo ""

# Delete volumes
DELETED_COUNT=0
FAILED_COUNT=0

echo "$ORPHAN_VOLUMES" | while read vol_id size state az create_time; do
    if [ -n "$vol_id" ]; then
        if aws ec2 delete-volume --volume-id "$vol_id" --region "${AWS_REGION}" 2>/dev/null; then
            DELETED_COUNT=$((DELETED_COUNT + 1))
            log_info "  ✓ Deleted: $vol_id"
        else
            FAILED_COUNT=$((FAILED_COUNT + 1))
            log_warning "  ✗ Failed to delete: $vol_id"
        fi
        
        # Progress indicator every 10 volumes
        TOTAL=$((DELETED_COUNT + FAILED_COUNT))
        if [ $((TOTAL % 10)) -eq 0 ]; then
            echo "    Progress: ${TOTAL}/${VOLUME_COUNT} processed..."
        fi
    fi
done

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║  ✅ BULK VOLUME CLEANUP COMPLETE!                        ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

Cleanup Summary:
  Total volumes processed: ${VOLUME_COUNT}
  Storage freed: ${TOTAL_SIZE_TB} TB (${TOTAL_SIZE_GB} GB)
  Estimated monthly savings: \$${TOTAL_SIZE_GB}.00

Note: It may take a few minutes for the volumes to fully disappear
from the AWS console.

EOF

log_info "Cleanup completed at $(date)"
