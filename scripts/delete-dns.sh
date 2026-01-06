#!/bin/bash
# Delete DNS Records
# Internal script - called by lab-cleanup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"

log_info "Removing DNS records for Team ${TEAM_NUMBER}..."

# Get current ALB info from state files or AWS
ALB_ZONE=$(cat "state/team${TEAM_NUMBER}/alb-zone.txt" 2>/dev/null || echo "")
ALB_DNS=$(cat "state/team${TEAM_NUMBER}/alb-dns.txt" 2>/dev/null || echo "")

# If state files are missing, try to get from AWS
if [ -z "$ALB_ZONE" ] || [ -z "$ALB_DNS" ]; then
    log_warning "State files missing, querying Route53 for DNS records..."
    
    # Get the actual records from Route53
    RECORDS_FILE="/tmp/dns-records-team${TEAM_NUMBER}-$$.json"
    aws route53 list-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --output json > "$RECORDS_FILE" 2>/dev/null || true
fi

# Function to delete a single DNS record by name
delete_dns_record() {
    local record_name=$1
    
    log_info "  Deleting: $record_name"
    
    # Get the existing record from Route53
    RECORD_JSON=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --query "ResourceRecordSets[?Name=='${record_name}.']" \
        --output json 2>/dev/null)
    
    # Check if record exists
    if [ "$RECORD_JSON" = "[]" ] || [ -z "$RECORD_JSON" ]; then
        log_warning "    Record not found, skipping: $record_name"
        return 0
    fi
    
    # Extract the record details
    RECORD_DETAILS=$(echo "$RECORD_JSON" | jq '.[0]')
    
    if [ -z "$RECORD_DETAILS" ] || [ "$RECORD_DETAILS" = "null" ]; then
        log_warning "    Could not parse record details for: $record_name"
        return 0
    fi
    
    # Create delete change batch
    CHANGE_BATCH=$(cat <<EOF
{
    "Changes": [{
        "Action": "DELETE",
        "ResourceRecordSet": $RECORD_DETAILS
    }]
}
EOF
)
    
    # Execute deletion
    if aws route53 change-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --change-batch "$CHANGE_BATCH" \
        --output json > /dev/null 2>&1; then
        log_success "    ✓ Deleted: $record_name"
        return 0
    else
        log_warning "    Failed to delete: $record_name"
        return 1
    fi
}

# Delete team-specific DNS records
DELETED_COUNT=0
FAILED_COUNT=0

# List of DNS records to delete for this team
DNS_RECORDS=(
    "controller-team${TEAM_NUMBER}.splunkylabs.com"
    "customer1-team${TEAM_NUMBER}.auth.splunkylabs.com"
    "customer1-tnt-authn-team${TEAM_NUMBER}.splunkylabs.com"
    "*.team${TEAM_NUMBER}.splunkylabs.com"
)

for record in "${DNS_RECORDS[@]}"; do
    if delete_dns_record "$record"; then
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    sleep 1  # Rate limiting
done

# Summary
echo ""
if [ $FAILED_COUNT -eq 0 ]; then
    log_success "DNS records removed (${DELETED_COUNT} deleted, ${FAILED_COUNT} failed)"
else
    log_warning "DNS cleanup completed with errors (${DELETED_COUNT} deleted, ${FAILED_COUNT} failed)"
fi

# Cleanup temp files
rm -f "/tmp/dns-records-team${TEAM_NUMBER}-$$.json"
