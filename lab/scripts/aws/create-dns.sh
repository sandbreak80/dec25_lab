#!/bin/bash
# Create DNS Records
# Internal script - called by lab-deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"
check_aws_cli

log_info "Configuring DNS for Team ${TEAM_NUMBER}..."

# Get ALB info
ALB_DNS=$(cat "state/team${TEAM_NUMBER}/alb-dns.txt")
ALB_ZONE=$(cat "state/team${TEAM_NUMBER}/alb-zone.txt")

# Create Route 53 change batch
cat > "/tmp/dns-team${TEAM_NUMBER}.json" << EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "controller-team${TEAM_NUMBER}.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "customer1-team${TEAM_NUMBER}.auth.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "customer1-tnt-authn-team${TEAM_NUMBER}.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "*.team${TEAM_NUMBER}.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

log_info "Creating DNS records in Route 53..."
aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "file:///tmp/dns-team${TEAM_NUMBER}.json"

log_success "DNS records created!"
log_info "Controller:  https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/"
log_info "Auth:        https://customer1-team${TEAM_NUMBER}.auth.splunkylabs.com/"
log_info "Wildcard:    *.team${TEAM_NUMBER}.splunkylabs.com → $ALB_DNS"

# Save URLs
cat > "state/team${TEAM_NUMBER}/urls.txt" << EOF
Controller: https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/
Auth:       https://customer1-team${TEAM_NUMBER}.auth.splunkylabs.com/
Wildcard:   *.team${TEAM_NUMBER}.splunkylabs.com
EOF

log_info "URLs saved to: state/team${TEAM_NUMBER}/urls.txt"
