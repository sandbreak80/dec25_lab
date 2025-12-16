#!/bin/bash
# Non-Interactive Full Deployment Script
# Deploys a complete AppDynamics lab environment from start to finish
# Usage: ./deployment/full-deploy.sh --team TEAM_NUMBER [--skip-password-change] [--skip-ssh-keys]

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${MAGENTA}${BOLD}▶ $1${NC}"; }

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Full Non-Interactive AppDynamics Deployment           ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [OPTIONS]

Required:
    --team, -t NUMBER    Team number (1-5)

Options:
    --skip-password-change    Skip password change step (use default)
    --skip-ssh-keys          Skip SSH key setup (use password auth only)
    --skip-verify            Skip final verification step
    --help, -h               Show this help

Example:
    # Full deployment with all steps
    $0 --team 5

    # Deployment skipping password change (faster for testing)
    $0 --team 5 --skip-password-change

Note: This script is fully non-interactive and takes 70-80 minutes.

EOF
}

# Parse arguments
TEAM_NUMBER=""
SKIP_PASSWORD_CHANGE=false
SKIP_SSH_KEYS=false
SKIP_VERIFY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--team)
            TEAM_NUMBER="$2"
            shift 2
            ;;
        --skip-password-change)
            SKIP_PASSWORD_CHANGE=true
            shift
            ;;
        --skip-ssh-keys)
            SKIP_SSH_KEYS=true
            shift
            ;;
        --skip-verify)
            SKIP_VERIFY=true
            shift
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

# Validate team number
if [ -z "$TEAM_NUMBER" ]; then
    log_error "Team number is required"
    show_usage
    exit 1
fi

if ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
    log_error "Team number must be between 1 and 5"
    exit 1
fi

# Create log directory
LOG_DIR="${PROJECT_ROOT}/logs/full-deploy"
mkdir -p "$LOG_DIR"
DEPLOY_LOG="${LOG_DIR}/team${TEAM_NUMBER}-$(date +%Y%m%d-%H%M%S).log"

# Log function that outputs to both console and file
log_both() {
    echo -e "$1" | tee -a "$DEPLOY_LOG"
}

# Track timing
START_TIME=$(date +%s)
STEP_START_TIME=$START_TIME

step_timer() {
    local step_name=$1
    local current_time=$(date +%s)
    local step_duration=$((current_time - STEP_START_TIME))
    local total_duration=$((current_time - START_TIME))
    
    log_both "${CYAN}⏱️  Step completed in ${step_duration}s (Total: ${total_duration}s)${NC}"
    STEP_START_TIME=$current_time
}

# Header
clear
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   🚀 Full Non-Interactive AppDynamics Deployment 🚀      ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF

echo ""
log_info "Team: ${TEAM_NUMBER}"
log_info "Started: $(date)"
log_info "Log file: $DEPLOY_LOG"
log_info "Estimated time: 70-80 minutes"
echo ""

if [ "$SKIP_PASSWORD_CHANGE" = true ]; then
    log_warning "Password change will be SKIPPED (using default: changeme)"
fi
if [ "$SKIP_SSH_KEYS" = true ]; then
    log_warning "SSH key setup will be SKIPPED (using password auth)"
fi

echo ""
log_warning "This is a NON-INTERACTIVE deployment. Do not interrupt!"
echo ""
sleep 3

# Track failures
FAILED_STEPS=()

run_step() {
    local step_number=$1
    local step_name=$2
    local step_script=$3
    shift 3
    local step_args="$@"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$DEPLOY_LOG"
    log_both "${MAGENTA}${BOLD}[$step_number/10] $step_name${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$DEPLOY_LOG"
    
    log_both "${BLUE}Running: $step_script $step_args${NC}"
    echo "" | tee -a "$DEPLOY_LOG"
    
    if "$step_script" $step_args 2>&1 | tee -a "$DEPLOY_LOG"; then
        log_both "${GREEN}✅ Step $step_number completed successfully${NC}"
        step_timer "$step_name"
        return 0
    else
        log_both "${RED}❌ Step $step_number FAILED${NC}"
        FAILED_STEPS+=("$step_number: $step_name")
        return 1
    fi
}

# Change to project root
cd "$PROJECT_ROOT"

# =============================================================================
# STEP 1: Prerequisites Check
# =============================================================================
run_step 1 "Prerequisites Check" \
    "${PROJECT_ROOT}/scripts/check-prerequisites.sh"

# =============================================================================
# STEP 2: Deploy Infrastructure
# =============================================================================
run_step 2 "Deploy Infrastructure (VPC, Subnets, Security Groups, VMs, ALB, DNS)" \
    "${SCRIPT_DIR}/01-deploy.sh" --team "$TEAM_NUMBER"

# =============================================================================
# STEP 3: Change Password (OPTIONAL - can be skipped for testing)
# =============================================================================
if [ "$SKIP_PASSWORD_CHANGE" = false ]; then
    run_step 3 "Change VM Password" \
        "${SCRIPT_DIR}/02-change-password.sh" --team "$TEAM_NUMBER"
else
    echo "" | tee -a "$DEPLOY_LOG"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$DEPLOY_LOG"
    log_both "${MAGENTA}${BOLD}[3/10] Change VM Password${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$DEPLOY_LOG"
    log_both "${YELLOW}⏭️  SKIPPED (using default password: changeme)${NC}"
fi

# =============================================================================
# STEP 4: Setup SSH Keys (OPTIONAL - can be skipped, password auth works)
# =============================================================================
if [ "$SKIP_SSH_KEYS" = false ]; then
    run_step 4 "Setup SSH Keys (Optional)" \
        "${SCRIPT_DIR}/03-setup-ssh-keys.sh" --team "$TEAM_NUMBER" || {
        log_warning "SSH key setup failed, continuing with password auth..."
    }
else
    echo "" | tee -a "$DEPLOY_LOG"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$DEPLOY_LOG"
    log_both "${MAGENTA}${BOLD}[4/10] Setup SSH Keys${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$DEPLOY_LOG"
    log_both "${YELLOW}⏭️  SKIPPED (using password authentication)${NC}"
fi

# =============================================================================
# STEP 5: Bootstrap VMs (15-20 minutes)
# =============================================================================
run_step 5 "Bootstrap VMs (15-20 min - extracts container images)" \
    "${SCRIPT_DIR}/04-bootstrap-vms.sh" --team "$TEAM_NUMBER"

# =============================================================================
# STEP 6: Create Kubernetes Cluster (10 minutes)
# =============================================================================
run_step 6 "Create Kubernetes Cluster (10 min)" \
    "${SCRIPT_DIR}/05-create-cluster.sh" --team "$TEAM_NUMBER"

# =============================================================================
# STEP 7: Configure AppDynamics (1 minute)
# =============================================================================
run_step 7 "Configure AppDynamics (globals.yaml.gotmpl)" \
    "${SCRIPT_DIR}/06-configure.sh" --team "$TEAM_NUMBER"

# =============================================================================
# STEP 8: Install AppDynamics Services (20-30 minutes)
# =============================================================================
run_step 8 "Install AppDynamics Services (20-30 min)" \
    "${SCRIPT_DIR}/07-install.sh" --team "$TEAM_NUMBER"

# =============================================================================
# STEP 9: Apply License (1 minute)
# =============================================================================
run_step 9 "Apply AppDynamics License" \
    "${SCRIPT_DIR}/09-apply-license.sh" --team "$TEAM_NUMBER"

# =============================================================================
# STEP 10: Verify Deployment (1 minute)
# =============================================================================
if [ "$SKIP_VERIFY" = false ]; then
    run_step 10 "Verify Deployment" \
        "${SCRIPT_DIR}/08-verify.sh" --team "$TEAM_NUMBER" || {
        log_warning "Verification had issues, but deployment may still be functional"
    }
else
    echo "" | tee -a "$DEPLOY_LOG"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$DEPLOY_LOG"
    log_both "${MAGENTA}${BOLD}[10/10] Verify Deployment${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$DEPLOY_LOG"
    log_both "${YELLOW}⏭️  SKIPPED${NC}"
fi

# =============================================================================
# SUMMARY
# =============================================================================
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
HOURS=$((TOTAL_DURATION / 3600))
MINUTES=$(((TOTAL_DURATION % 3600) / 60))
SECONDS=$((TOTAL_DURATION % 60))

echo "" | tee -a "$DEPLOY_LOG"
echo "" | tee -a "$DEPLOY_LOG"
cat << "EOF" | tee -a "$DEPLOY_LOG"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║              DEPLOYMENT COMPLETE!                        ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF

echo "" | tee -a "$DEPLOY_LOG"

if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    log_both "${GREEN}${BOLD}✅ All steps completed successfully!${NC}"
else
    log_both "${RED}${BOLD}❌ ${#FAILED_STEPS[@]} step(s) failed:${NC}"
    for step in "${FAILED_STEPS[@]}"; do
        log_both "${RED}   - $step${NC}"
    done
fi

echo "" | tee -a "$DEPLOY_LOG"
log_both "${CYAN}📊 Deployment Summary:${NC}"
log_both "   Team: ${TEAM_NUMBER}"
log_both "   Started: $(date -d @${START_TIME} 2>/dev/null || date -r ${START_TIME})"
log_both "   Completed: $(date)"
log_both "   Duration: ${HOURS}h ${MINUTES}m ${SECONDS}s"
log_both "   Log: $DEPLOY_LOG"

echo "" | tee -a "$DEPLOY_LOG"
log_both "${CYAN}🌐 Access URLs:${NC}"
log_both "   Controller: https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/"
log_both "   Events: https://events-team${TEAM_NUMBER}.splunkylabs.com/"
log_both "   SecureApp: https://secureapp-team${TEAM_NUMBER}.splunkylabs.com/"

echo "" | tee -a "$DEPLOY_LOG"
log_both "${CYAN}🔐 Credentials:${NC}"
log_both "   VM SSH: appduser / AppDynamics123!"
log_both "   Controller: admin / welcome"

echo "" | tee -a "$DEPLOY_LOG"
log_both "${CYAN}📝 Next Steps:${NC}"
log_both "   1. Access Controller and verify license"
log_both "   2. Change admin password"
log_both "   3. Test monitoring with sample app"

echo "" | tee -a "$DEPLOY_LOG"
log_both "${CYAN}🗑️  Cleanup:${NC}"
log_both "   ./deployment/cleanup.sh --team ${TEAM_NUMBER} --confirm"

echo "" | tee -a "$DEPLOY_LOG"

if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    log_both "${GREEN}${BOLD}🎉 Deployment successful! Environment is ready!${NC}"
    exit 0
else
    log_both "${RED}${BOLD}⚠️  Deployment completed with errors. Check log for details.${NC}"
    exit 1
fi

