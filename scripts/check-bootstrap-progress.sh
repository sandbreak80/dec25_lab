#!/bin/bash
# Monitor AppDynamics VM Bootstrap Progress

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Check AppDynamics Bootstrap Progress                   ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [--watch]

Arguments:
    --team, -t NUMBER    Your team number (1-5)
    --watch, -w          Continuously monitor (refresh every 30s)
    --help, -h           Show this help

Example:
    $0 --team 1
    $0 --team 1 --watch

This script monitors the bootstrap progress of AppDynamics VMs.
The bootstrap process extracts multi-GB image files and typically takes 20-30 minutes.

EOF
    exit 1
}

TEAM_NUMBER=""
WATCH_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --watch|-w) WATCH_MODE=true; shift ;;
        --help|-h) show_usage ;;
        *) log_error "Unknown parameter: $1"; show_usage ;;
    esac
done

if [[ -z "$TEAM_NUMBER" ]] || ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
    log_error "Team number must be 1-5"
    show_usage
fi

load_team_config "$TEAM_NUMBER" > /dev/null 2>&1

# Get SSH key path
KEY_PATH=$(cat "state/team${TEAM_NUMBER}/ssh-key-path.txt" 2>/dev/null || echo "")
PASSWORD="AppDynamics123!"

if [[ -z "$KEY_PATH" ]] || [[ ! -f "$KEY_PATH" ]]; then
    log_error "SSH key not found. Has infrastructure been deployed?"
    exit 1
fi

check_bootstrap_progress() {
    if [ "$WATCH_MODE" = true ]; then
        clear
    fi
    
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  AppDynamics Bootstrap Progress - Team ${TEAM_NUMBER}               ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    date
    echo ""
    
    ALL_COMPLETE=true
    
    for i in 1 2 3; do
        VM_IP=$(cat "state/team${TEAM_NUMBER}/vm${i}-public-ip.txt" 2>/dev/null)
        
        if [[ -z "$VM_IP" ]]; then
            echo "VM${i}: ❌ Not deployed"
            ALL_COMPLETE=false
            continue
        fi
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "VM${i} (${VM_IP}):"
        echo ""
        
        # Check if appd-os service is active
        SERVICE_STATUS=$(ssh -i "${KEY_PATH}" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o LogLevel=ERROR \
            appduser@${VM_IP} "echo '${PASSWORD}' | sudo -S systemctl is-active appd-os 2>/dev/null" 2>&1 | grep -v "password")
        
        if [[ "$SERVICE_STATUS" != "active" ]]; then
            echo "  ❌ appd-os service is not active"
            ALL_COMPLETE=false
            continue
        fi
        
        echo "  ✅ appd-os service: active"
        
        # Check if bootstrap is complete
        BOOT_STATUS=$(ssh -i "${KEY_PATH}" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o LogLevel=ERROR \
            appduser@${VM_IP} "appdctl show boot 2>&1" 2>&1)
        
        if echo "$BOOT_STATUS" | grep -q "Socket /var/run/appd-os.sock not found"; then
            echo "  ⏳ Bootstrap in progress..."
            echo ""
            
            # Show extraction progress
            EXTRACT_PROCS=$(ssh -i "${KEY_PATH}" \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o LogLevel=ERROR \
                appduser@${VM_IP} "echo '${PASSWORD}' | sudo -S ps aux 2>/dev/null | grep 'unxz' | grep -v grep" 2>&1 | grep -v "password")
            
            if [[ -n "$EXTRACT_PROCS" ]]; then
                echo "  📦 Extracting images:"
                echo "$EXTRACT_PROCS" | while read line; do
                    if echo "$line" | grep -q "infra-images"; then
                        ELAPSED=$(echo "$line" | awk '{print $10}')
                        echo "     - infra-images (running for ${ELAPSED})"
                    elif echo "$line" | grep -q "aiops-images"; then
                        ELAPSED=$(echo "$line" | awk '{print $10}')
                        echo "     - aiops-images (running for ${ELAPSED})"
                    fi
                done
            fi
            
            ALL_COMPLETE=false
        elif echo "$BOOT_STATUS" | grep -q "Succeeded"; then
            echo "  ✅ Bootstrap COMPLETE!"
            echo ""
            echo "$BOOT_STATUS" | sed 's/^/     /'
        else
            echo "  ⚠️  Unknown status:"
            echo "$BOOT_STATUS" | sed 's/^/     /'
            ALL_COMPLETE=false
        fi
        
        echo ""
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ "$ALL_COMPLETE" = true ]; then
        echo "🎉 All VMs bootstrapped successfully!"
        echo ""
        return 0
    else
        echo "⏱️  Bootstrap still in progress. This typically takes 20-30 minutes."
        echo ""
        if [ "$WATCH_MODE" = false ]; then
            echo "Run with --watch to continuously monitor progress."
        fi
        return 1
    fi
}

if [ "$WATCH_MODE" = true ]; then
    while true; do
        check_bootstrap_progress
        if [ $? -eq 0 ]; then
            break
        fi
        echo "Refreshing in 30 seconds... (Ctrl+C to stop)"
        sleep 30
    done
else
    check_bootstrap_progress
fi

