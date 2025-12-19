#!/bin/bash
# MySQL Health Check and Auto-Recovery Script
# Monitors MySQL status and automatically restores if needed
# Reference: common_issues.md - "Restore the MySQL Service"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   MySQL Health Check & Auto-Recovery                    ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [OPTIONS]

Options:
    --team, -t NUMBER      Team number (1-5)
    --max-retries NUM      Maximum retry attempts (default: 3)
    --wait-time SECONDS    Wait time between retries (default: 60)
    --fix                  Attempt automatic fix if unhealthy
    --help, -h             Show this help

Description:
    Checks MySQL cluster health and automatically restores MySQL
    service if needed. Common issue: MySQL doesn't auto-start
    after VM restart (80% occurrence rate during deployments).

Examples:
    # Check health
    $0 --team 1

    # Check and auto-fix if needed
    $0 --team 1 --fix

    # Check with custom retry settings
    $0 --team 1 --fix --max-retries 5 --wait-time 90

Returns:
    0 - MySQL healthy
    1 - MySQL unhealthy (not fixed)
    2 - MySQL restored successfully

Reference: common_issues.md - "Restore the MySQL Service"

EOF
}

# Parse arguments
TEAM_NUMBER=""
MAX_RETRIES=3
WAIT_TIME=60
AUTO_FIX=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --max-retries) MAX_RETRIES="$2"; shift 2 ;;
        --wait-time) WAIT_TIME="$2"; shift 2 ;;
        --fix) AUTO_FIX=true; shift ;;
        --help|-h) show_usage; exit 0 ;;
        *) log_error "Unknown parameter: $1"; show_usage; exit 1 ;;
    esac
done

if [ -z "$TEAM_NUMBER" ]; then
    log_error "Team number is required"
    show_usage
    exit 1
fi

load_team_config "$TEAM_NUMBER"

# Get VM1 IP
VM1_IP=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt" 2>/dev/null)
if [ -z "$VM1_IP" ]; then
    log_error "VM1 IP not found. Has infrastructure been deployed?"
    exit 1
fi

PASSWORD="AppDynamics123!"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

log_info "Checking MySQL health for Team ${TEAM_NUMBER}..."
echo ""

# Function to check MySQL health via SSH
check_mysql_health() {
    log_info "Running infrastructure inspection..."
    
    INFRA_OUTPUT=$(expect << EOF 2>&1
set timeout 30
spawn ssh $SSH_OPTS appduser@$VM1_IP "appdcli run infra_inspect"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    timeout { puts "TIMEOUT"; exit 1 }
    eof
}
EOF
)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to connect to VM1"
        return 1
    fi
    
    # Parse output
    echo "$INFRA_OUTPUT" > /tmp/mysql-check-team${TEAM_NUMBER}.txt
    
    # Check for MySQL pods
    MYSQL_PODS=$(echo "$INFRA_OUTPUT" | grep "appd-mysql" | wc -l)
    MYSQL_RUNNING=$(echo "$INFRA_OUTPUT" | grep "appd-mysql" | grep "Running" | wc -l)
    MYSQL_READY=$(echo "$INFRA_OUTPUT" | grep "appd-mysql-[0-2]" | grep "2/2" | wc -l)
    MYSQL_ROUTER_RUNNING=$(echo "$INFRA_OUTPUT" | grep "appd-mysql-router" | grep "Running" | wc -l)
    
    echo ""
    log_info "MySQL Cluster Status:"
    echo "  Total MySQL pods found: $MYSQL_PODS"
    echo "  MySQL pods running: $MYSQL_RUNNING"
    echo "  MySQL pods ready (2/2): $MYSQL_READY"
    echo "  MySQL router pods running: $MYSQL_ROUTER_RUNNING"
    echo ""
    
    # Health criteria: Need 3 MySQL pods (2/2 ready) and 3 router pods running
    if [ "$MYSQL_READY" -ge 3 ] && [ "$MYSQL_ROUTER_RUNNING" -ge 3 ]; then
        log_success "MySQL cluster is healthy!"
        return 0
    else
        log_warning "MySQL cluster is unhealthy or not fully started"
        
        # Show detailed status
        echo ""
        echo "Detailed Status:"
        echo "$INFRA_OUTPUT" | grep -E "(appd-mysql|NAME)" | sed 's/^/  /'
        echo ""
        
        return 1
    fi
}

# Function to restore MySQL
restore_mysql() {
    log_info "Attempting MySQL restore..."
    echo ""
    
    RESTORE_OUTPUT=$(expect << EOF 2>&1
set timeout 300
spawn ssh $SSH_OPTS appduser@$VM1_IP "appdcli run mysql_restore"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    timeout { puts "TIMEOUT"; exit 1 }
    eof
}
EOF
)
    
    if [ $? -ne 0 ]; then
        log_error "MySQL restore command failed"
        echo "$RESTORE_OUTPUT" | tail -20 | sed 's/^/  /'
        return 1
    fi
    
    log_success "MySQL restore command completed"
    echo ""
    
    # Wait for MySQL to stabilize
    log_info "Waiting ${WAIT_TIME} seconds for MySQL to stabilize..."
    sleep "$WAIT_TIME"
    
    return 0
}

# Main health check
if check_mysql_health; then
    log_success "MySQL health check passed"
    exit 0
fi

# MySQL is unhealthy
if [ "$AUTO_FIX" = false ]; then
    log_warning "MySQL is unhealthy. Use --fix to attempt automatic recovery."
    echo ""
    echo "Manual recovery:"
    echo "  ssh appduser@${VM1_IP}"
    echo "  appdcli run mysql_restore"
    echo ""
    exit 1
fi

# Attempt automatic recovery
log_warning "MySQL is unhealthy. Attempting automatic recovery..."
echo ""

for attempt in $(seq 1 $MAX_RETRIES); do
    log_info "Recovery attempt $attempt of $MAX_RETRIES..."
    echo ""
    
    if restore_mysql; then
        log_info "Verifying MySQL health after restore..."
        echo ""
        
        if check_mysql_health; then
            echo ""
            log_success "MySQL successfully restored and verified!"
            log_success "Cluster is now healthy"
            exit 2  # Return 2 to indicate successful restoration
        else
            log_warning "MySQL restore completed but cluster still unhealthy"
            
            if [ $attempt -lt $MAX_RETRIES ]; then
                log_info "Will retry in ${WAIT_TIME} seconds..."
                sleep "$WAIT_TIME"
            fi
        fi
    else
        log_error "MySQL restore attempt failed"
        
        if [ $attempt -lt $MAX_RETRIES ]; then
            log_info "Retrying in ${WAIT_TIME} seconds..."
            sleep "$WAIT_TIME"
        fi
    fi
done

# All retries exhausted
echo ""
log_error "Failed to restore MySQL after $MAX_RETRIES attempts"
echo ""
echo "Manual intervention required:"
echo "  1. SSH to VM1: ssh appduser@${VM1_IP}"
echo "  2. Run: appdcli run mysql_restore"
echo "  3. Wait 2-3 minutes"
echo "  4. Verify: appdcli run infra_inspect"
echo ""
echo "Expected healthy output:"
echo "  appd-mysql-0      2/2  Running"
echo "  appd-mysql-1      2/2  Running"
echo "  appd-mysql-2      2/2  Running"
echo "  appd-mysql-router pods (3x) Running"
echo ""
exit 1

