#!/bin/bash
# Configure SecureApp Vulnerability Feeds
# This script sets up automatic vulnerability feed downloads for SecureApp
# Usage: ./10-configure-secureapp.sh --team N [--username USERNAME] [--password PASSWORD]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Configure SecureApp Vulnerability Feeds               ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [OPTIONS]

Required:
    --team, -t NUMBER          Team number (1-5)

Optional:
    --username USER            AppDynamics portal username
    --password PASS            AppDynamics portal password
    --skip-restart             Don't trigger immediate feed download
    --help, -h                 Show this help

Description:
    Configures SecureApp to automatically download vulnerability feeds
    from AppDynamics servers. Requires valid portal credentials.

Prerequisites:
    1. SecureApp must be installed (run 07-install.sh first)
    2. Valid AppDynamics portal account (non-admin user recommended)
    3. Internet connectivity to download.appdynamics.com

Portal Account Setup:
    1. Log in to https://accounts.appdynamics.com/
    2. Create a dedicated user (e.g., 'feed-downloader')
    3. Assign basic user role (no admin privileges needed)
    4. Note the username and password

Environment Variables:
    APPD_PORTAL_USERNAME       Portal username (alternative to --username)
    APPD_PORTAL_PASSWORD       Portal password (alternative to --password)

Examples:
    # Interactive (will prompt for password):
    $0 --team 1 --username feed-downloader

    # Using environment variables:
    export APPD_PORTAL_USERNAME=feed-downloader
    export APPD_PORTAL_PASSWORD=SecurePass123
    $0 --team 1

    # Non-interactive with credentials:
    $0 --team 1 --username feed-downloader --password SecurePass123

Time Required: 2-3 minutes + 5-10 minutes for initial feed download

EOF
}

# Parse arguments
TEAM_NUMBER=""
PORTAL_USERNAME="${APPD_PORTAL_USERNAME:-}"
PORTAL_PASSWORD="${APPD_PORTAL_PASSWORD:-}"
SKIP_RESTART=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t)
            TEAM_NUMBER="$2"
            shift 2
            ;;
        --username)
            PORTAL_USERNAME="$2"
            shift 2
            ;;
        --password)
            PORTAL_PASSWORD="$2"
            shift 2
            ;;
        --skip-restart)
            SKIP_RESTART=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown parameter: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$TEAM_NUMBER" ]; then
    log_error "Team number is required"
    show_usage
    exit 1
fi

# Load team configuration
load_team_config "$TEAM_NUMBER"

# Setup logging
LOG_FILE="${LOG_DIR}/team${TEAM_NUMBER}-10-secureapp-config-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

log_section "Configure SecureApp Vulnerability Feeds - Team ${TEAM_NUMBER}"

# Get VM1 public IP
VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt" 2>/dev/null || echo "")
if [ -z "$VM1_PUB" ]; then
    log_error "Cannot find VM1 public IP. Has deployment completed?"
    exit 1
fi

log_info "VM1 Public IP: $VM1_PUB"

# Check if SecureApp is installed
log_info "Verifying SecureApp installation..."
if ! expect << EOF | grep -q "cisco-secureapp"
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB}
expect "password:"
send "${VM_DEFAULT_PASSWORD}\r"
expect "$ "
send "kubectl get namespace cisco-secureapp 2>&1\r"
expect "$ "
send "exit\r"
expect eof
EOF
then
    log_error "SecureApp namespace not found. Install SecureApp first (07-install.sh)"
    exit 1
fi

log_success "SecureApp is installed"

# Get portal credentials if not provided
if [ -z "$PORTAL_USERNAME" ]; then
    log_warning "No portal username provided"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  AppDynamics Portal Credentials Required"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "To enable automatic vulnerability feed downloads, you need:"
    echo ""
    echo "1. A user account at https://accounts.appdynamics.com/"
    echo "2. Recommended: Create a dedicated non-admin user for feeds"
    echo "   Example username: feed-downloader"
    echo ""
    read -p "Enter AppDynamics portal username: " PORTAL_USERNAME
    
    if [ -z "$PORTAL_USERNAME" ]; then
        log_error "Username is required to configure feeds"
        exit 1
    fi
fi

log_info "Portal username: $PORTAL_USERNAME"

# Prepare password for expect script
if [ -z "$PORTAL_PASSWORD" ]; then
    log_info "Password will be prompted interactively on the VM"
    INTERACTIVE_MODE=true
else
    log_info "Using provided password"
    INTERACTIVE_MODE=false
fi

# Configure portal credentials
log_info "Configuring portal credentials on Team ${TEAM_NUMBER} VM..."
echo ""

if [ "$INTERACTIVE_MODE" = true ]; then
    # Interactive mode - let user type password directly on VM
    log_info "You will be prompted to enter the portal password on the VM"
    log_info "Type the password when prompted and press Enter"
    echo ""
    
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        appduser@${VM1_PUB} << EOSSH
appdcli run secureapp setDownloadPortalCredentials ${PORTAL_USERNAME}
EOSSH
    
else
    # Non-interactive mode - use expect to provide password
    expect << EOF
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB}
expect "password:"
send "${VM_DEFAULT_PASSWORD}\r"
expect "$ "
send "appdcli run secureapp setDownloadPortalCredentials ${PORTAL_USERNAME}\r"
expect {
    "Enter password for portal user" {
        send "${PORTAL_PASSWORD}\r"
        exp_continue
    }
    "successfully" {
        send "exit\r"
    }
    "failed" {
        send "exit\r"
        exit 1
    }
    timeout {
        send "exit\r"
        exit 1
    }
}
expect eof
EOF
    
    if [ $? -ne 0 ]; then
        log_error "Failed to configure portal credentials"
        log_error "Possible causes:"
        log_error "  - Incorrect username or password"
        log_error "  - Network connectivity issues"
        log_error "  - Portal account issues"
        exit 1
    fi
fi

log_success "Portal credentials configured!"

# Restart feed processing to trigger immediate download
if [ "$SKIP_RESTART" = false ]; then
    log_info "Triggering immediate feed download..."
    
    expect << EOF
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB}
expect "password:"
send "${VM_DEFAULT_PASSWORD}\r"
expect "$ "
send "appdcli run secureapp restartFeedProcessing\r"
expect "$ "
send "exit\r"
expect eof
EOF
    
    log_success "Feed processing restarted"
    log_info "Initial feed download will take 5-10 minutes"
else
    log_info "Skipping immediate feed download (will download on daily schedule)"
fi

# Display verification instructions
echo ""
log_section "Verification Steps"
echo ""
echo "The feed download is now running in the background."
echo ""
echo "To verify the configuration:"
echo ""
echo "1. Wait 5-10 minutes for initial feed download"
echo ""
echo "2. Check feed status:"
echo "   ssh appduser@${VM1_PUB}"
echo "   appdcli run secureapp numAgentReports"
echo "   # Should show: Feed Entries: XXXXX (number > 0)"
echo ""
echo "3. Check SecureApp health:"
echo "   appdcli ping | grep SecureApp"
echo "   # Should show: | SecureApp | Success |"
echo ""
echo "4. View vuln pod logs:"
echo "   kubectl logs -n cisco-secureapp \$(kubectl get pods -n cisco-secureapp -l app=vuln -o name | head -1) --tail=30"
echo ""

# Save configuration status
echo "configured" > "state/team${TEAM_NUMBER}/secureapp-feeds-configured.flag"
echo "$PORTAL_USERNAME" > "state/team${TEAM_NUMBER}/secureapp-portal-username.txt"
date > "state/team${TEAM_NUMBER}/secureapp-feeds-config-date.txt"

log_success "SecureApp feed configuration complete!"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ SecureApp Feed Configuration Complete!              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration Details:"
echo "  Team: ${TEAM_NUMBER}"
echo "  Portal User: ${PORTAL_USERNAME}"
echo "  VM: ${VM1_PUB}"
echo "  Feed Download: Automatic (daily)"
echo ""
echo "Next Steps:"
echo "  1. Wait 5-10 minutes for initial feed download"
echo "  2. Verify with: appdcli run secureapp numAgentReports"
echo "  3. Check: appdcli ping | grep SecureApp"
echo ""
echo "Note: Feeds will update automatically every 24 hours"
echo ""

# Mark step as complete
mark_step_complete "secureapp-feeds-configured" "$TEAM_NUMBER"


