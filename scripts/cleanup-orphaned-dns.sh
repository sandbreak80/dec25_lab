#!/bin/bash
# Cleanup orphaned DNS records from terminated labs
# This removes DNS records pointing to non-existent ALBs

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

HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-Z06491142QTF1FNN8O9PR}"
AWS_REGION="${AWS_REGION:-us-west-2}"

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Cleanup Orphaned DNS Records                          ║
╚══════════════════════════════════════════════════════════╝

This script will DELETE DNS records pointing to non-existent ALBs.

Hosted Zone: ${HOSTED_ZONE_ID}
Region:      ${AWS_REGION}

⚠️  WARNING: This will delete DNS records that cannot be resolved!

EOF

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS CLI is not configured or credentials are invalid"
    log_info "Run: aws configure"
    exit 1
fi

log_success "AWS CLI configured"
echo ""

# Get all A records and CNAME records (except SOA, NS, and TXT for ACM validation in use)
log_info "Fetching DNS records from hosted zone..."

RECORDS_FILE="/tmp/dns-records-$$.json"
aws route53 list-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --output json > "$RECORDS_FILE"

# Parse and check each A record
echo ""
log_info "Analyzing DNS records..."
echo ""

ORPHANED_RECORDS=()
KEEP_RECORDS=()

# Check A records pointing to ALBs
while IFS=$'\t' read -r record_type record_name record_value; do
    if [[ "$record_value" == *".elb.amazonaws.com." ]]; then
        # Extract ALB name from DNS
        ALB_DNS="$record_value"
        
        # Check if ALB exists
        log_info "Checking: $record_name -> $ALB_DNS"
        
        if aws elbv2 describe-load-balancers --region "$AWS_REGION" 2>/dev/null | \
           jq -e ".LoadBalancers[] | select(.DNSName == \"${ALB_DNS%?}\")" > /dev/null 2>&1; then
            log_success "  ✓ ALB exists - keeping record"
            KEEP_RECORDS+=("$record_name")
        else
            log_warning "  ✗ ALB not found - marking for deletion"
            ORPHANED_RECORDS+=("$record_type|$record_name|$record_value")
        fi
    fi
done < <(jq -r '.ResourceRecordSets[] | select(.Type == "A" and .ResourceRecords != null) | "\(.Type)\t\(.Name)\t\(.ResourceRecords[0].Value)"' "$RECORDS_FILE")

# Also check alias records
while IFS=$'\t' read -r record_type record_name alias_dns; do
    if [[ "$alias_dns" == *".elb.amazonaws.com." ]]; then
        log_info "Checking: $record_name -> $alias_dns (ALIAS)"
        
        if aws elbv2 describe-load-balancers --region "$AWS_REGION" 2>/dev/null | \
           jq -e ".LoadBalancers[] | select(.DNSName == \"${alias_dns%?}\")" > /dev/null 2>&1; then
            log_success "  ✓ ALB exists - keeping record"
            KEEP_RECORDS+=("$record_name")
        else
            log_warning "  ✗ ALB not found - marking for deletion"
            ORPHANED_RECORDS+=("$record_type|$record_name|$alias_dns")
        fi
    fi
done < <(jq -r '.ResourceRecordSets[] | select(.Type == "A" and .AliasTarget != null) | "\(.Type)\t\(.Name)\t\(.AliasTarget.DNSName)"' "$RECORDS_FILE")

echo ""

if [ ${#ORPHANED_RECORDS[@]} -eq 0 ]; then
    log_success "No orphaned DNS records found!"
    rm -f "$RECORDS_FILE"
    exit 0
fi

# Show summary
log_warning "Found ${#ORPHANED_RECORDS[@]} orphaned DNS record(s):"
echo ""
for record in "${ORPHANED_RECORDS[@]}"; do
    IFS='|' read -r type name value <<< "$record"
    echo "  - $name ($type -> $value)"
done

echo ""
log_info "These records will be DELETED from the hosted zone."
echo ""

# Final confirmation
read -p "Type 'DELETE DNS RECORDS' to proceed: " confirmation

if [ "$confirmation" != "DELETE DNS RECORDS" ]; then
    log_error "Confirmation failed. Exiting."
    rm -f "$RECORDS_FILE"
    exit 1
fi

echo ""
log_info "Starting DNS record deletion..."
echo ""

# Delete records using change batch
DELETED_COUNT=0
FAILED_COUNT=0

for record in "${ORPHANED_RECORDS[@]}"; do
    IFS='|' read -r type name value <<< "$record"
    
    # Get the full record details from the original JSON
    RECORD_JSON=$(jq --arg name "$name" --arg type "$type" \
        '.ResourceRecordSets[] | select(.Name == $name and .Type == $type)' \
        "$RECORDS_FILE")
    
    if [ -z "$RECORD_JSON" ]; then
        log_error "  ✗ Could not find record details for $name"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
    fi
    
    # Create change batch
    CHANGE_BATCH=$(cat <<EOF
{
    "Changes": [{
        "Action": "DELETE",
        "ResourceRecordSet": $RECORD_JSON
    }]
}
EOF
)
    
    # Execute deletion
    if aws route53 change-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --change-batch "$CHANGE_BATCH" \
        --output json > /dev/null 2>&1; then
        log_success "  ✓ Deleted: $name"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        log_error "  ✗ Failed to delete: $name"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    
    # Small delay to avoid rate limiting
    sleep 1
done

# Cleanup
rm -f "$RECORDS_FILE"

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║  ✅ DNS CLEANUP COMPLETE!                                ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

Cleanup Summary:
  Records deleted:  ${DELETED_COUNT}
  Records failed:   ${FAILED_COUNT}
  Records kept:     ${#KEEP_RECORDS[@]}

EOF

if [ ${#KEEP_RECORDS[@]} -gt 0 ]; then
    log_info "Active records preserved:"
    for record in "${KEEP_RECORDS[@]}"; do
        echo "  - $record"
    done
    echo ""
fi

log_info "DNS cleanup completed at $(date)"
