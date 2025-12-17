#!/bin/bash
# Delete DNS Records
# Internal script - called by lab-cleanup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"

log_info "Removing DNS records for Team ${TEAM_NUMBER}..."

# Create delete change batch
cat > "/tmp/dns-delete-team${TEAM_NUMBER}.json" << EOF
{
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "controller-team${TEAM_NUMBER}.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$(cat state/team${TEAM_NUMBER}/alb-zone.txt 2>/dev/null)",
          "DNSName": "$(cat state/team${TEAM_NUMBER}/alb-dns.txt 2>/dev/null)",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "customer1-team${TEAM_NUMBER}.auth.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$(cat state/team${TEAM_NUMBER}/alb-zone.txt 2>/dev/null)",
          "DNSName": "$(cat state/team${TEAM_NUMBER}/alb-dns.txt 2>/dev/null)",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "customer1-tnt-authn-team${TEAM_NUMBER}.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$(cat state/team${TEAM_NUMBER}/alb-zone.txt 2>/dev/null)",
          "DNSName": "$(cat state/team${TEAM_NUMBER}/alb-dns.txt 2>/dev/null)",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "*.team${TEAM_NUMBER}.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$(cat state/team${TEAM_NUMBER}/alb-zone.txt 2>/dev/null)",
          "DNSName": "$(cat state/team${TEAM_NUMBER}/alb-dns.txt 2>/dev/null)",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "file:///tmp/dns-delete-team${TEAM_NUMBER}.json" >/dev/null 2>&1 || true

log_success "DNS records removed"
