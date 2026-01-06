#!/bin/bash
# Delete Orphaned Route53 Hosted Zone
# Safely removes the unused duplicate hosted zone for splunkylabs.com

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

ACTIVE_ZONE_ID="Z06491142QTF1FNN8O9PR"
ORPHANED_ZONE_ID="Z0008805DDX7D9TKACJ5"
DOMAIN="splunkylabs.com"

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Delete Orphaned Route53 Hosted Zone                  ║
╚══════════════════════════════════════════════════════════╝

This script will DELETE the duplicate hosted zone for ${DOMAIN}

EOF

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS CLI is not configured or credentials are invalid"
    log_info "Run: aws configure"
    exit 1
fi

log_success "AWS CLI configured"
echo ""

# Verify both zones exist
log_info "Verifying hosted zones..."

ZONE1_EXISTS=$(aws route53 get-hosted-zone --id "$ACTIVE_ZONE_ID" --query 'HostedZone.Id' --output text 2>/dev/null || echo "")
ZONE2_EXISTS=$(aws route53 get-hosted-zone --id "$ORPHANED_ZONE_ID" --query 'HostedZone.Id' --output text 2>/dev/null || echo "")

if [ -z "$ZONE1_EXISTS" ]; then
    log_error "Active zone $ACTIVE_ZONE_ID not found!"
    exit 1
fi

if [ -z "$ZONE2_EXISTS" ]; then
    log_warning "Orphaned zone $ORPHANED_ZONE_ID not found (may already be deleted)"
    exit 0
fi

log_success "Both zones found"
echo ""

# Get nameservers for domain
log_info "Checking which zone is active..."
DOMAIN_NS=$(dig +short NS ${DOMAIN} | head -1)

ZONE1_NS=$(aws route53 get-hosted-zone --id "$ACTIVE_ZONE_ID" --query 'DelegationSet.NameServers[0]' --output text)
ZONE2_NS=$(aws route53 get-hosted-zone --id "$ORPHANED_ZONE_ID" --query 'DelegationSet.NameServers[0]' --output text)

echo ""
echo "Analysis:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Domain NS:  $DOMAIN_NS"
echo "Zone 1 NS:  $ZONE1_NS  (${ACTIVE_ZONE_ID})"
echo "Zone 2 NS:  $ZONE2_NS  (${ORPHANED_ZONE_ID})"
echo ""

if [[ "$DOMAIN_NS" == *"$ZONE1_NS"* ]] || [[ "$ZONE1_NS" == *"$DOMAIN_NS"* ]]; then
    log_success "Domain points to Zone 1 (${ACTIVE_ZONE_ID}) ✓"
    ACTIVE_CONFIRMED="$ACTIVE_ZONE_ID"
    ORPHANED_CONFIRMED="$ORPHANED_ZONE_ID"
elif [[ "$DOMAIN_NS" == *"$ZONE2_NS"* ]] || [[ "$ZONE2_NS" == *"$DOMAIN_NS"* ]]; then
    log_error "WARNING: Domain points to Zone 2 (${ORPHANED_ZONE_ID})!"
    log_error "Expected Zone 1 to be active. Please verify manually."
    exit 1
else
    log_warning "Could not determine which zone is active"
    log_warning "Domain may be using external nameservers"
fi

echo ""
echo "Zone 1 (${ACTIVE_ZONE_ID}) - ACTIVE:"
aws route53 list-resource-record-sets --hosted-zone-id "$ACTIVE_ZONE_ID" --query 'ResourceRecordSets[*].[Type,Name]' --output table | head -20

echo ""
echo "Zone 2 (${ORPHANED_ZONE_ID}) - ORPHANED:"
aws route53 list-resource-record-sets --hosted-zone-id "$ORPHANED_ZONE_ID" --query 'ResourceRecordSets[*].[Type,Name]' --output table

echo ""
log_warning "This will DELETE Zone 2 (${ORPHANED_ZONE_ID})"
log_info "Zone 1 (${ACTIVE_ZONE_ID}) will remain active"
echo ""
log_info "Cost savings: \$0.50/month (\$6/year)"
echo ""

# Final confirmation
read -p "Type 'DELETE ZONE' to proceed: " confirmation

if [ "$confirmation" != "DELETE ZONE" ]; then
    log_error "Confirmation failed. Exiting."
    exit 1
fi

echo ""
log_info "Deleting orphaned hosted zone..."

# Check if zone has only default records (NS and SOA)
RECORD_COUNT=$(aws route53 list-resource-record-sets --hosted-zone-id "$ORPHANED_ZONE_ID" --query 'length(ResourceRecordSets)' --output text)

if [ "$RECORD_COUNT" -gt 2 ]; then
    log_warning "Zone has $RECORD_COUNT records (more than just NS and SOA)"
    echo ""
    read -p "Delete anyway? (y/n): " confirm_delete
    if [ "$confirm_delete" != "y" ]; then
        log_error "Deletion cancelled"
        exit 1
    fi
    
    # Delete additional records first
    log_info "Removing additional records..."
    RECORDS=$(aws route53 list-resource-record-sets --hosted-zone-id "$ORPHANED_ZONE_ID" --output json)
    
    echo "$RECORDS" | jq -c '.ResourceRecordSets[] | select(.Type != "NS" and .Type != "SOA")' | while read record; do
        RECORD_NAME=$(echo "$record" | jq -r '.Name')
        RECORD_TYPE=$(echo "$record" | jq -r '.Type')
        
        log_info "  Deleting: $RECORD_TYPE $RECORD_NAME"
        
        CHANGE_BATCH=$(cat <<EOF
{
    "Changes": [{
        "Action": "DELETE",
        "ResourceRecordSet": $record
    }]
}
EOF
)
        
        aws route53 change-resource-record-sets \
            --hosted-zone-id "$ORPHANED_ZONE_ID" \
            --change-batch "$CHANGE_BATCH" \
            --output json > /dev/null 2>&1 || log_warning "    Failed to delete $RECORD_NAME"
        
        sleep 1
    done
fi

# Delete the hosted zone
log_info "Deleting hosted zone ${ORPHANED_ZONE_ID}..."

if aws route53 delete-hosted-zone --id "$ORPHANED_ZONE_ID" --output json > /dev/null 2>&1; then
    log_success "Hosted zone deleted successfully!"
else
    log_error "Failed to delete hosted zone"
    log_info "You may need to delete additional records first"
    exit 1
fi

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║  ✅ ORPHANED HOSTED ZONE DELETED!                        ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

Summary:
  Deleted zone: ${ORPHANED_ZONE_ID}
  Active zone:  ${ACTIVE_ZONE_ID}
  Cost savings: \$0.50/month (\$6/year)

Verification:
  You now have only 1 hosted zone for ${DOMAIN}
  All DNS records remain in the active zone

EOF

log_info "Cleanup completed at $(date)"
