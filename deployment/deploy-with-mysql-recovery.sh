#!/bin/bash
# Deployment with MySQL Auto-Recovery
# Wraps deployment steps with automatic MySQL health checking and recovery
# Addresses the 80% MySQL failure rate during builds

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Deployment with MySQL Auto-Recovery                   ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [OPTIONS]

Options:
    --team, -t NUMBER         Team number (1-5)
    --skip-mysql-check        Skip MySQL health checks
    --mysql-retries NUM       MySQL recovery attempts (default: 3)
    --help, -h                Show this help

Description:
    Enhanced deployment script that automatically detects and
    fixes MySQL issues during build. MySQL fails to start 80%
    of the time - this script handles it automatically.

Examples:
    # Deploy with automatic MySQL recovery
    $0 --team 1

    # Deploy with more aggressive MySQL recovery
    $0 --team 1 --mysql-retries 5

What it does:
    1. Runs deployment steps
    2. Checks MySQL health after bootstrap
    3. Auto-restores MySQL if needed
    4. Retries installation steps if MySQL fails
    5. Verifies everything is healthy before completing

Reference: common_issues.md - "Restore the MySQL Service"

EOF
}

# Parse arguments
TEAM_NUMBER=""
SKIP_MYSQL_CHECK=false
MYSQL_RETRIES=3

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --skip-mysql-check) SKIP_MYSQL_CHECK=true; shift ;;
        --mysql-retries) MYSQL_RETRIES="$2"; shift 2 ;;
        --help|-h) show_usage; exit 0 ;;
        *) log_error "Unknown parameter: $1"; show_usage; exit 1 ;;
    esac
done

if [ -z "$TEAM_NUMBER" ]; then
    log_error "Team number is required"
    show_usage
    exit 1
fi

# Create log directory
LOG_DIR="${PROJECT_ROOT}/logs/mysql-recovery"
mkdir -p "$LOG_DIR"
DEPLOY_LOG="${LOG_DIR}/team${TEAM_NUMBER}-$(date +%Y%m%d-%H%M%S).log"

log_both() {
    echo -e "$1" | tee -a "$DEPLOY_LOG"
}

# Header
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   Deployment with MySQL Auto-Recovery                   ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF

echo ""
log_info "Team: ${TEAM_NUMBER}"
log_info "MySQL Recovery: Enabled (max ${MYSQL_RETRIES} attempts)"
log_info "Log file: $DEPLOY_LOG"
echo ""

# Function to check MySQL health
check_mysql() {
    local context=$1
    
    if [ "$SKIP_MYSQL_CHECK" = true ]; then
        log_info "MySQL check skipped"
        return 0
    fi
    
    log_info "Checking MySQL health (${context})..."
    
    if "${PROJECT_ROOT}/scripts/check-mysql-health.sh" --team "$TEAM_NUMBER" --fix --max-retries "$MYSQL_RETRIES" 2>&1 | tee -a "$DEPLOY_LOG"; then
        MYSQL_STATUS=$?
        
        if [ $MYSQL_STATUS -eq 0 ]; then
            log_success "MySQL is healthy"
            return 0
        elif [ $MYSQL_STATUS -eq 2 ]; then
            log_success "MySQL was restored and is now healthy"
            return 0
        else
            log_error "MySQL health check failed"
            return 1
        fi
    else
        log_error "MySQL health check script failed"
        return 1
    fi
}

# Track start time
START_TIME=$(date +%s)

cd "$PROJECT_ROOT"

# =============================================================================
# PHASE 1: Infrastructure (01-deploy.sh)
# =============================================================================
log_both "${BLUE}▶ Phase 1: Deploying Infrastructure${NC}"
echo ""

if ! "${PROJECT_ROOT}/deployment/01-deploy.sh" --team "$TEAM_NUMBER" 2>&1 | tee -a "$DEPLOY_LOG"; then
    log_error "Infrastructure deployment failed"
    exit 1
fi

log_success "Infrastructure deployed"
echo ""

# =============================================================================
# PHASE 2: Password & SSH (02-03)
# =============================================================================
log_both "${BLUE}▶ Phase 2: Password and SSH Setup${NC}"
echo ""

"${PROJECT_ROOT}/deployment/02-change-password.sh" --team "$TEAM_NUMBER" 2>&1 | tee -a "$DEPLOY_LOG"
"${PROJECT_ROOT}/deployment/03-setup-ssh-keys.sh" --team "$TEAM_NUMBER" 2>&1 | tee -a "$DEPLOY_LOG"

log_success "Password and SSH configured"
echo ""

# =============================================================================
# PHASE 3: Bootstrap (04-bootstrap-vms.sh)
# =============================================================================
log_both "${BLUE}▶ Phase 3: Bootstrap VMs${NC}"
echo ""

"${PROJECT_ROOT}/deployment/04-bootstrap-vms.sh" --team "$TEAM_NUMBER" 2>&1 | tee -a "$DEPLOY_LOG"

log_success "Bootstrap initiated"
log_info "Waiting 15 minutes for image extraction..."
echo ""

# Show progress bar
for i in {1..15}; do
    echo -ne "  Progress: $i/15 minutes...\r"
    sleep 60
done
echo ""

log_success "Bootstrap wait complete"
echo ""

# =============================================================================
# PHASE 4: Create Cluster (05-create-cluster.sh)
# =============================================================================
log_both "${BLUE}▶ Phase 4: Create Kubernetes Cluster${NC}"
echo ""

# This is where MySQL often fails - attempt with retry logic
MAX_CLUSTER_ATTEMPTS=2
CLUSTER_SUCCESS=false

for cluster_attempt in $(seq 1 $MAX_CLUSTER_ATTEMPTS); do
    log_info "Cluster creation attempt $cluster_attempt of $MAX_CLUSTER_ATTEMPTS..."
    echo ""
    
    if "${PROJECT_ROOT}/deployment/05-create-cluster.sh" --team "$TEAM_NUMBER" 2>&1 | tee -a "$DEPLOY_LOG"; then
        log_success "Cluster creation completed"
        echo ""
        
        # CRITICAL: Check MySQL health after cluster creation
        log_warning "⚠️  MySQL often fails here (80% occurrence) - checking health..."
        echo ""
        
        if check_mysql "after cluster creation"; then
            CLUSTER_SUCCESS=true
            break
        else
            log_error "MySQL is unhealthy after cluster creation"
            
            if [ $cluster_attempt -lt $MAX_CLUSTER_ATTEMPTS ]; then
                log_warning "Will retry cluster creation..."
                sleep 60
            fi
        fi
    else
        log_error "Cluster creation failed"
        
        if [ $cluster_attempt -lt $MAX_CLUSTER_ATTEMPTS ]; then
            log_warning "Retrying cluster creation in 60 seconds..."
            sleep 60
        fi
    fi
done

if [ "$CLUSTER_SUCCESS" = false ]; then
    log_error "Cluster creation failed after $MAX_CLUSTER_ATTEMPTS attempts"
    log_error "MySQL could not be stabilized"
    echo ""
    echo "Manual recovery steps:"
    echo "  1. SSH to VM1"
    echo "  2. Run: appdcli run mysql_restore"
    echo "  3. Wait 2-3 minutes"
    echo "  4. Verify: appdcli run infra_inspect"
    echo "  5. Re-run deployment: ./deployment/06-configure.sh --team $TEAM_NUMBER"
    echo ""
    exit 1
fi

log_success "Cluster is healthy and ready"
echo ""

# =============================================================================
# PHASE 5: Configure (06-configure.sh)
# =============================================================================
log_both "${BLUE}▶ Phase 5: Configure AppDynamics${NC}"
echo ""

"${PROJECT_ROOT}/deployment/06-configure.sh" --team "$TEAM_NUMBER" 2>&1 | tee -a "$DEPLOY_LOG"

log_success "Configuration complete"
echo ""

# =============================================================================
# PHASE 6: Install AppDynamics (07-install.sh)
# =============================================================================
log_both "${BLUE}▶ Phase 6: Install AppDynamics Services${NC}"
echo ""

# Check MySQL one more time before installation
check_mysql "before AppDynamics installation"

"${PROJECT_ROOT}/deployment/07-install.sh" --team "$TEAM_NUMBER" 2>&1 | tee -a "$DEPLOY_LOG"

log_success "AppDynamics installation complete"
echo ""

# =============================================================================
# PHASE 7: Final MySQL Health Check
# =============================================================================
log_both "${BLUE}▶ Phase 7: Final Health Verification${NC}"
echo ""

check_mysql "final verification"

log_success "Final health check passed"
echo ""

# =============================================================================
# PHASE 8: Apply License (09-apply-license.sh)
# =============================================================================
log_both "${BLUE}▶ Phase 8: Apply License${NC}"
echo ""

"${PROJECT_ROOT}/deployment/09-apply-license.sh" --team "$TEAM_NUMBER" 2>&1 | tee -a "$DEPLOY_LOG"

log_success "License applied"
echo ""

# =============================================================================
# COMPLETION
# =============================================================================
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
HOURS=$((TOTAL_DURATION / 3600))
MINUTES=$(((TOTAL_DURATION % 3600) / 60))

echo ""
cat << "EOF" | tee -a "$DEPLOY_LOG"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║      DEPLOYMENT COMPLETE WITH MYSQL AUTO-RECOVERY        ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF

echo ""
log_both "${GREEN}✅ Deployment successful with MySQL auto-recovery!${NC}"
echo ""
log_both "Duration: ${HOURS}h ${MINUTES}m"
log_both "Log: $DEPLOY_LOG"
echo ""
log_both "MySQL Status: Verified healthy"
echo ""
log_both "Access URLs:"
log_both "  Controller: https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/"
echo ""
log_both "Next steps:"
log_both "  1. Verify deployment: ./scripts/check-deployment-state.sh"
log_both "  2. Configure SecureApp: ./deployment/10-configure-secureapp.sh --team ${TEAM_NUMBER}"
echo ""

exit 0

