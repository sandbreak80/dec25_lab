#!/bin/bash
# Verify EUM Configuration for Team Deployment
# Usage: ./verify-eum-config.sh --team TEAM_NUMBER

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Verify EUM Configuration                              ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER

Verifies EUM and Events Service configuration for a team deployment.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help

This script checks:
  1. EUM pods are running
  2. Events pods are running
  3. EUM endpoints are accessible
  4. Events endpoints are accessible
  5. Ingress routing is configured
  6. DNS resolution works

EOF
}

# Parse arguments
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
            log_error "Unknown argument: $1"
            show_usage
            exit 1
            ;;
    esac
done

if [[ -z "$TEAM_NUMBER" ]]; then
    log_error "Team number is required"
    show_usage
    exit 1
fi

# Validate team number
if ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
    log_error "Team number must be between 1 and 5"
    exit 1
fi

# Load team configuration
TEAM_CONFIG="${SCRIPT_DIR}/../config/team${TEAM_NUMBER}.cfg"
if [[ ! -f "$TEAM_CONFIG" ]]; then
    log_error "Team configuration not found: $TEAM_CONFIG"
    exit 1
fi

source "$TEAM_CONFIG"

cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Verify EUM Configuration - Team ${TEAM_NUMBER}                  ║
╚══════════════════════════════════════════════════════════╝

Team: ${TEAM_NAME}
Controller URL: https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller

EOF

# Get VM IP
STATE_DIR="${SCRIPT_DIR}/../state/team${TEAM_NUMBER}"
if [[ ! -d "$STATE_DIR" ]]; then
    log_error "Team state directory not found: $STATE_DIR"
    exit 1
fi

VM1_PUBLIC_IP=$(cat "${STATE_DIR}/vm1-public-ip.txt" 2>/dev/null || echo "")
if [[ -z "$VM1_PUBLIC_IP" ]]; then
    log_error "Could not find VM1 public IP"
    exit 1
fi

PASSWORD="AppDynamics123!"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

echo ""
log_info "Step 1: Checking EUM pods status..."

EUM_PODS=$(ssh $SSH_OPTS appduser@${VM1_PUBLIC_IP} "kubectl get pods -n cisco-eum --no-headers 2>/dev/null" || echo "SSH_ERROR")

if [[ "$EUM_PODS" == "SSH_ERROR" ]]; then
    log_error "Could not SSH to VM1. Check connectivity and password."
    exit 1
fi

echo "$EUM_PODS"
if echo "$EUM_PODS" | grep -q "Running"; then
    log_success "EUM pods are running"
else
    log_error "EUM pods are not running properly"
    echo "Check pod status: ssh appduser@${VM1_PUBLIC_IP} kubectl get pods -n cisco-eum"
fi

echo ""
log_info "Step 2: Checking Events Service pods status..."

EVENTS_PODS=$(ssh $SSH_OPTS appduser@${VM1_PUBLIC_IP} "kubectl get pods -n cisco-events --no-headers 2>/dev/null" || echo "")
echo "$EVENTS_PODS"
if echo "$EVENTS_PODS" | grep -q "Running"; then
    log_success "Events Service pods are running"
else
    log_error "Events Service pods are not running properly"
fi

echo ""
log_info "Step 3: Testing EUM Collector endpoint..."

CONTROLLER_URL="https://controller-team${TEAM_NUMBER}.splunkylabs.com"

# Test EUM Collector
EUM_COLLECTOR_TEST=$(curl -k -s -o /dev/null -w "%{http_code}" "${CONTROLLER_URL}/eumcollector/health" 2>/dev/null || echo "FAIL")
if [[ "$EUM_COLLECTOR_TEST" =~ ^[2-3][0-9]{2}$ ]]; then
    log_success "EUM Collector endpoint responding (HTTP $EUM_COLLECTOR_TEST)"
else
    log_error "EUM Collector endpoint not responding"
    echo "URL tested: ${CONTROLLER_URL}/eumcollector/health"
fi

echo ""
log_info "Step 4: Testing EUM Aggregator endpoint..."

EUM_AGGREGATOR_TEST=$(curl -k -s -o /dev/null -w "%{http_code}" "${CONTROLLER_URL}/eumaggregator/health" 2>/dev/null || echo "FAIL")
if [[ "$EUM_AGGREGATOR_TEST" =~ ^[2-3][0-9]{2}$ ]]; then
    log_success "EUM Aggregator endpoint responding (HTTP $EUM_AGGREGATOR_TEST)"
else
    log_error "EUM Aggregator endpoint not responding"
    echo "URL tested: ${CONTROLLER_URL}/eumaggregator/health"
fi

echo ""
log_info "Step 5: Testing Events Service endpoint..."

EVENTS_TEST=$(curl -k -s -o /dev/null -w "%{http_code}" "${CONTROLLER_URL}/events/health" 2>/dev/null || echo "FAIL")
if [[ "$EVENTS_TEST" =~ ^[2-3][0-9]{2}$ ]]; then
    log_success "Events Service endpoint responding (HTTP $EVENTS_TEST)"
else
    log_error "Events Service endpoint not responding"
    echo "URL tested: ${CONTROLLER_URL}/events/health"
fi

echo ""
log_info "Step 6: Checking appdcli ping status..."

APPDCLI_PING=$(ssh $SSH_OPTS appduser@${VM1_PUBLIC_IP} "appdcli ping 2>/dev/null | grep -i eum" || echo "")
echo "$APPDCLI_PING"

if echo "$APPDCLI_PING" | grep -qi "success"; then
    log_success "EUM service status: Success"
elif echo "$APPDCLI_PING" | grep -qi "failed"; then
    log_warning "EUM service status: Failed (may be feed downloader issue - see common_issues.md)"
else
    log_error "Could not determine EUM service status"
fi

echo ""
log_info "Step 7: Checking DNS resolution..."

DNS_TEST=$(nslookup "controller-team${TEAM_NUMBER}.splunkylabs.com" 2>/dev/null | grep -A1 "Name:" || echo "DNS_FAIL")
if [[ "$DNS_TEST" != "DNS_FAIL" ]]; then
    log_success "DNS resolving correctly"
    echo "$DNS_TEST"
else
    log_error "DNS resolution failed"
fi

echo ""
log_info "Step 8: Checking ingress configuration..."

INGRESS_INFO=$(ssh $SSH_OPTS appduser@${VM1_PUBLIC_IP} "kubectl get ingress -n cisco-controller -o wide 2>/dev/null" || echo "")
if [[ -n "$INGRESS_INFO" ]]; then
    echo "$INGRESS_INFO"
    log_success "Ingress configured"
else
    log_warning "Could not retrieve ingress information"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Verification Summary                                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Team ${TEAM_NUMBER} EUM Configuration Status:"
echo ""
echo "Controller URL: ${CONTROLLER_URL}/controller"
echo "EUM Collector:  ${CONTROLLER_URL}/eumcollector"
echo "EUM Aggregator: ${CONTROLLER_URL}/eumaggregator"
echo "Events Service: ${CONTROLLER_URL}/events"
echo ""
echo "Next Steps:"
echo ""
echo "1. Configure admin.jsp Controller Settings:"
echo "   URL: ${CONTROLLER_URL}/controller/admin.jsp"
echo "   Username: root"
echo "   Password: welcome (or your root password)"
echo ""
echo "2. Update these properties (use filter box to find them):"
echo "   - eum.beacon.host: ${CONTROLLER_URL}/eumcollector"
echo "   - eum.beacon.https.host: ${CONTROLLER_URL}/eumcollector"
echo "   - eum.cloud.host: ${CONTROLLER_URL}/eumaggregator"
echo "   - eum.es.host: controller-team${TEAM_NUMBER}.splunkylabs.com:443"
echo "   - appdynamics.on.premise.event.service.url: ${CONTROLLER_URL}/events"
echo "   - eum.mobile.screenshot.host: ${CONTROLLER_URL}/screenshots"
echo ""
echo "3. See detailed guide: docs/TEAM5_EUM_ADMIN_CONFIG.md"
echo ""
echo "4. After configuration, create a Browser App in Controller UI"
echo "   and verify JavaScript snippet has correct beacon URLs"
echo ""


