#!/bin/bash
# 00-preflight-check.sh
# Pre-flight validation before AppDynamics VA deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Load configuration
if [ ! -f "${SCRIPT_DIR}/config/deployment.conf" ]; then
    echo "❌ Configuration file not found: config/deployment.conf"
    echo "   Copy config/deployment.conf.example and customize it"
    exit 1
fi

source "${SCRIPT_DIR}/config/deployment.conf"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

print_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

print_check() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
    ((ERRORS++))
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# Check 1: AWS Resources
check_aws_resources() {
    print_check "Checking AWS resources..."
    
    # Verify instances are running
    NODES=("$NODE1_IP:$NODE1_HOSTNAME" "$NODE2_IP:$NODE2_HOSTNAME" "$NODE3_IP:$NODE3_IP")
    
    for node_info in "${NODES[@]}"; do
        node_ip="${node_info%%:*}"
        node_name="${node_info##*:}"
        
        if ping -c 1 -W 2 "$node_ip" &>/dev/null; then
            print_success "Node $node_name ($node_ip) is reachable"
        else
            print_error "Cannot reach $node_name ($node_ip)"
        fi
    done
}

# Check 2: DNS Resolution
check_dns() {
    print_check "Checking DNS configuration..."
    
    # Critical DNS records
    REQUIRED_DOMAINS=(
        "${TENANT_NAME}.auth.${DNS_DOMAIN}"
        "${TENANT_NAME}-tnt-authn.${DNS_DOMAIN}"
    )
    
    for domain in "${REQUIRED_DOMAINS[@]}"; do
        if host "$domain" "$DNS_SERVER" &>/dev/null; then
            resolved_ip=$(host "$domain" "$DNS_SERVER" | grep "has address" | awk '{print $4}' | head -1)
            if [ "$resolved_ip" == "$INGRESS_IP" ]; then
                print_success "DNS resolves correctly: $domain → $resolved_ip"
            else
                print_error "DNS resolves to wrong IP: $domain → $resolved_ip (expected: $INGRESS_IP)"
            fi
        else
            print_error "DNS record not found: $domain"
            echo "         Configure DNS to point $domain to $INGRESS_IP"
        fi
    done
}

# Check 3: SSH Access
check_ssh_access() {
    print_check "Checking SSH access to nodes..."
    
    for node_info in "${NODES[@]}"; do
        node_ip="${node_info%%:*}"
        node_name="${node_info##*:}"
        
        if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no \
            appduser@"$node_ip" "exit" 2>/dev/null; then
            print_success "SSH access verified for $node_name ($node_ip)"
        else
            print_error "Cannot SSH to $node_name ($node_ip)"
            echo "         Run: ssh-copy-id appduser@$node_ip"
            echo "         Default password: changeme"
        fi
    done
}

# Check 4: Disk Space
check_disk_space() {
    print_check "Checking disk space on nodes..."
    
    for node_info in "${NODES[@]}"; do
        node_ip="${node_info%%:*}"
        node_name="${node_info##*:}"
        
        if ! ssh -o ConnectTimeout=5 appduser@"$node_ip" "exit" 2>/dev/null; then
            print_warning "Skipping disk check for $node_name (SSH not available)"
            continue
        fi
        
        os_space=$(ssh appduser@"$node_ip" "df -BG / | tail -1 | awk '{print \$4}' | sed 's/G//'" 2>/dev/null || echo "0")
        
        if [ "$os_space" -gt 50 ]; then
            print_success "$node_name - OS disk: ${os_space}GB available"
        else
            print_error "$node_name - Insufficient OS disk space: ${os_space}GB (need 50GB+)"
        fi
    done
}

# Check 5: Required Files
check_required_files() {
    print_check "Checking required files..."
    
    # License file
    if [ -n "$LICENSE_FILE_PATH" ] && [ -f "$LICENSE_FILE_PATH" ]; then
        print_success "License file found: $LICENSE_FILE_PATH"
    else
        print_warning "License file not found: $LICENSE_FILE_PATH"
        echo "         You can apply license later using: appdcli license controller license.lic"
    fi
    
    # Custom certificates
    if [ "$USE_CUSTOM_CERTS" = "true" ]; then
        if [ -f "$CERT_PATH" ]; then
            # Check certificate validity
            if openssl x509 -in "$CERT_PATH" -noout -checkend 86400 2>/dev/null; then
                expiry=$(openssl x509 -in "$CERT_PATH" -noout -enddate 2>/dev/null | cut -d= -f2)
                print_success "Certificate valid until: $expiry"
            else
                print_warning "Certificate expires within 24 hours"
            fi
        else
            print_error "Certificate not found: $CERT_PATH"
        fi
        
        if [ -f "$KEY_PATH" ]; then
            print_success "Private key found: $KEY_PATH"
        else
            print_error "Private key not found: $KEY_PATH"
        fi
    else
        print_success "Using default self-signed certificates"
    fi
}

# Check 6: Configuration Values
check_configuration() {
    print_check "Validating configuration..."
    
    # Check deployment profile
    case "$DEPLOYMENT_PROFILE" in
        small|medium|large)
            print_success "Deployment profile: $DEPLOYMENT_PROFILE"
            ;;
        *)
            print_error "Invalid deployment profile: $DEPLOYMENT_PROFILE (must be small, medium, or large)"
            ;;
    esac
    
    # Check IP addresses are valid
    for ip_var in NODE1_IP NODE2_IP NODE3_IP GATEWAY_IP DNS_SERVER INGRESS_IP; do
        ip_value="${!ip_var}"
        if [[ $ip_value =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            print_success "$ip_var is valid: $ip_value"
        else
            print_error "$ip_var is invalid: $ip_value"
        fi
    done
    
    # Check tenant name format
    if [[ $TENANT_NAME =~ ^[a-z0-9-]+$ ]]; then
        print_success "Tenant name is valid: $TENANT_NAME"
    else
        print_error "Tenant name must be lowercase alphanumeric with hyphens: $TENANT_NAME"
    fi
}

# Check 7: Network Connectivity
check_network() {
    print_check "Checking network connectivity..."
    
    # Check internet access from nodes
    for node_info in "${NODES[@]}"; do
        node_ip="${node_info%%:*}"
        node_name="${node_info##*:}"
        
        if ! ssh -o ConnectTimeout=5 appduser@"$node_ip" "exit" 2>/dev/null; then
            print_warning "Skipping network check for $node_name (SSH not available)"
            continue
        fi
        
        if ssh appduser@"$node_ip" "curl -s -m 5 https://www.google.com > /dev/null" 2>/dev/null; then
            print_success "$node_name has internet access"
        else
            print_warning "$node_name may not have internet access"
        fi
    done
}

# Main execution
print_header "AppDynamics VA Pre-flight Checks"

echo "Deployment Configuration:"
echo "  Environment: $ENVIRONMENT_NAME"
echo "  DNS Domain: $DNS_DOMAIN"
echo "  Tenant: $TENANT_NAME"
echo "  Profile: $DEPLOYMENT_PROFILE"
echo "  Nodes: $NODE1_HOSTNAME, $NODE2_HOSTNAME, $NODE3_HOSTNAME"
echo ""

check_configuration
check_required_files
check_aws_resources
check_ssh_access
check_disk_space
check_dns
check_network

print_header "Pre-flight Check Summary"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "Ready to proceed with deployment:"
    echo "  1. Run: ./01-bootstrap-all-vms.sh"
    echo "  2. Run: ./02-create-cluster.sh"
    echo "  3. Run: ./03-generate-configs.sh"
    echo "  4. Run: ./04-install-services.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo ""
    echo "You can proceed, but review warnings above"
    exit 0
else
    echo -e "${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found${NC}"
    echo ""
    echo "Please fix errors before proceeding with deployment"
    exit 1
fi
