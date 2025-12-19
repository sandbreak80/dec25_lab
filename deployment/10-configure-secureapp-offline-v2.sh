#!/bin/bash
#
# Configure SecureApp with Direct Pod Upload (Bypass API)
# Usage: ./10-configure-secureapp-offline-v2.sh --team TEAM_NUMBER
#
# This script:
# 1. Downloads a pre-exported SecureApp feed from S3
# 2. Uploads it to the AppDynamics VM
# 3. Copies it directly into the vuln pod
# 4. Restarts feed processing
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# S3 bucket and feed file
S3_BUCKET="appd-va-bucket-stoner-lab"
FEED_FILE="secapp_data_25.12.18.1765984004.dat"
S3_PATH="s3://${S3_BUCKET}/secureapp-feeds/${FEED_FILE}"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Configure SecureApp with Direct Pod Upload            ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [OPTIONS]

Required:
    --team, -t NUMBER    Team number (1-5)

Options:
    --help, -h           Show this help

This script imports a pre-exported SecureApp vulnerability feed
by copying it directly into the vuln pod, bypassing API issues.

Feed source: ${S3_PATH}

EOF
}

TEAM_NUMBER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--team)
            TEAM_NUMBER="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

if [ -z "$TEAM_NUMBER" ]; then
    log_error "Team number is required"
    show_usage
    exit 1
fi

load_team_config "$TEAM_NUMBER"

VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt")
TEMP_DIR="/tmp/secureapp-feed"
REMOTE_PATH="/home/appduser/${FEED_FILE}"

log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "   SecureApp Direct Pod Upload - Team ${TEAM_NUMBER}"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =============================================================================
# STEP 1: Download feed from S3
# =============================================================================
echo ""
log_info "▶ Step 1: Download feed from S3"
mkdir -p "$TEMP_DIR"
log_info "Downloading ${FEED_FILE} from S3..."

if aws s3 cp "$S3_PATH" "${TEMP_DIR}/${FEED_FILE}"; then
    FEED_SIZE=$(du -h "${TEMP_DIR}/${FEED_FILE}" | cut -f1)
    log_success "✅ Downloaded ${FEED_SIZE} feed file from S3"
else
    log_error "Failed to download feed from S3. Check AWS credentials and bucket permissions."
    exit 1
fi

# =============================================================================
# STEP 2: Upload feed to VM
# =============================================================================
echo ""
log_info "▶ Step 2: Upload feed to VM1 (${VM1_PUB})"
log_info "Uploading ${FEED_SIZE} to VM..."

expect << EOF
set timeout 600
spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${TEMP_DIR}/${FEED_FILE}" "appduser@${VM1_PUB}:${REMOTE_PATH}"
expect "password:"
send "AppDynamics123!\r"
expect eof
EOF

if [ $? -eq 0 ]; then
    log_success "✅ Feed uploaded to VM"
else
    log_error "Failed to upload feed to VM. Check SSH connectivity."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Cleanup local temp file
rm -rf "$TEMP_DIR"

# =============================================================================
# STEP 3: Copy feed into vuln pod and extract
# =============================================================================
echo ""
log_info "▶ Step 3: Copy feed into vuln pod"
log_info "Finding vuln pod and copying feed directly..."

expect << EOF
set timeout 600
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB}
expect "password:"
send "AppDynamics123!\r"
expect "$ "

send "echo '=== Finding vuln pod ==='\r"
expect "$ "
send "VULN_POD=\\\$(kubectl get pods -n cisco-secureapp -l app=vuln -o name | head -1 | cut -d'/' -f2)\r"
expect "$ "
send "echo Found vuln pod: \\\$VULN_POD\r"
expect "$ "

send "echo '=== Copying feed into pod ==='\r"
expect "$ "
send "kubectl cp ${REMOTE_PATH} cisco-secureapp/\\\$VULN_POD:/tmp/${FEED_FILE}\r"
expect "$ "

send "echo '=== Extracting feed in pod ==='\r"
expect "$ "
send "kubectl exec -n cisco-secureapp \\\$VULN_POD -- mkdir -p /var/appd/data/feeds\r"
expect "$ "
send "kubectl exec -n cisco-secureapp \\\$VULN_POD -- tar -xzf /tmp/${FEED_FILE} -C /var/appd/data/feeds/\r"
expect {
    "error" {
        send "echo 'EXTRACT_ERROR'\r"
        exp_continue
    }
    "$ " {
        send "echo 'EXTRACT_SUCCESS'\r"
    }
    timeout {
        send "echo 'EXTRACT_TIMEOUT'\r"
    }
}
expect "$ "

send "echo '=== Cleaning up ==='\r"
expect "$ "
send "rm -f ${REMOTE_PATH}\r"
expect "$ "
send "kubectl exec -n cisco-secureapp \\\$VULN_POD -- rm -f /tmp/${FEED_FILE}\r"
expect "$ "

send "echo '=== Restarting feed processing ==='\r"
expect "$ "
send "appdcli run secureapp restartFeedProcessing\r"
expect "$ "

send "exit\r"
expect eof
EOF

if [ $? -eq 0 ]; then
    log_success "✅ Feed copied into vuln pod"
else
    log_error "Failed to copy feed into pod."
    exit 1
fi

# =============================================================================
# STEP 4: Wait and verify
# =============================================================================
echo ""
log_info "▶ Step 4: Wait for feed processing"
log_info "Waiting 3 minutes for feeds to be processed..."
sleep 180

echo ""
log_info "▶ Step 5: Verify SecureApp status"
log_info "Checking SecureApp health..."

HEALTH_OUTPUT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    appduser@${VM1_PUB} "appdcli run secureapp health" 2>&1 <<< "AppDynamics123!")

echo "$HEALTH_OUTPUT" | grep -q "Feed Entries:" && {
    FEED_ENTRIES=$(echo "$HEALTH_OUTPUT" | grep "Feed Entries:" | awk '{print $3}')
    if [[ "$FEED_ENTRIES" -gt 0 ]]; then
        log_success "✅✅✅ SecureApp feeds imported successfully! Found $FEED_ENTRIES entries."
    else
        log_warning "⚠️ SecureApp feeds showing 0 entries. May need more time to process."
    fi
}

PING_OUTPUT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    appduser@${VM1_PUB} "appdcli ping | grep SecureApp" 2>&1 <<< "AppDynamics123!")

echo "$PING_OUTPUT" | grep -q "Success" && {
    log_success "✅ SecureApp status: SUCCESS"
} || {
    log_warning "⚠️ SecureApp status: ${PING_OUTPUT}"
}

echo ""
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "SecureApp direct pod upload complete for Team ${TEAM_NUMBER}"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "SecureApp UI: https://team${TEAM_NUMBER}.splunkylabs.com/controller/"
log_info "(Login with admin/welcome, navigate to Secure Application)"
echo ""

mark_step_complete "secureapp-offline-feeds-imported" "$TEAM_NUMBER"


