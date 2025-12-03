# Post-Deployment Automation Plan

## Goal
Automate the 50+ manual steps required after AWS infrastructure deployment to install and configure AppDynamics services.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Deployment Orchestrator                   │
│                      (Ansible/Terraform)                     │
└──────────────┬──────────────────────────────────────────────┘
               │
               ├── Pre-flight Checks
               │   ├── Network connectivity
               │   ├── DNS resolution
               │   ├── Storage availability
               │   ├── AWS resources ready
               │   └── Certificates valid
               │
               ├── VM Bootstrap
               │   ├── Configure hostname/IP on all 3 nodes
               │   ├── Verify boot status
               │   └── Validate readiness
               │
               ├── Configuration Generation
               │   ├── Generate globals.yaml from template
               │   ├── Generate secrets.yaml with secure passwords
               │   ├── Generate certificate configs
               │   └── Validate YAML syntax
               │
               ├── Cluster Formation
               │   ├── Initialize cluster on primary
               │   ├── Join peer nodes
               │   ├── Verify cluster health
               │   └── Wait for readiness
               │
               ├── Service Installation
               │   ├── Copy license files
               │   ├── Install core services
               │   ├── Install optional services
               │   ├── Monitor installation progress
               │   └── Verify service health
               │
               └── Post-Install Validation
                   ├── Check all endpoints
                   ├── Verify service status
                   ├── Generate health report
                   └── Output access credentials
```

---

## Implementation: Ansible Approach

### Directory Structure
```
ansible/
├── inventory/
│   ├── hosts.ini                 # Dynamic from AWS
│   └── group_vars/
│       └── all.yml              # Common variables
├── roles/
│   ├── preflight/               # Pre-deployment checks
│   ├── bootstrap/               # VM initialization
│   ├── cluster/                 # Cluster formation
│   ├── appd-core/              # Core services install
│   ├── appd-optional/          # Optional services
│   └── validation/             # Post-install checks
├── templates/
│   ├── globals.yaml.j2
│   ├── secrets.yaml.j2
│   ├── dns-config.j2
│   └── license-config.j2
├── playbooks/
│   ├── 00-preflight.yml
│   ├── 01-bootstrap-vms.yml
│   ├── 02-create-cluster.yml
│   ├── 03-install-services.yml
│   ├── 04-validate.yml
│   └── site.yml                # Master playbook
└── README.md
```

### Key Benefits
- Idempotent operations (safe to re-run)
- Parallel execution where possible
- Built-in error handling and rollback
- Configuration validation before apply
- Comprehensive logging
- Easy to version control

---

## Alternative: Scripted Approach with Bash

For simpler deployment without Ansible:

### Script Structure
```
scripts/
├── 00-preflight-check.sh
├── 01-bootstrap-all-vms.sh
├── 02-create-cluster.sh
├── 03-generate-configs.sh
├── 04-install-core-services.sh
├── 05-install-optional-services.sh
├── 06-validate-deployment.sh
├── lib/
│   ├── common.sh              # Shared functions
│   ├── logging.sh             # Logging utilities
│   ├── validation.sh          # Validation functions
│   └── colors.sh              # Terminal colors
├── templates/
│   ├── globals.yaml.template
│   └── secrets.yaml.template
└── config/
    └── deployment.conf        # User inputs
```

---

## Configuration Management

### Input Configuration File (`deployment.conf`)
```bash
# Network Configuration
DNS_DOMAIN="va.mycompany.com"
TENANT_NAME="customer1"
INGRESS_IP="10.0.0.100"

# Node Configuration (populated from AWS)
NODE1_IP="10.0.0.10"
NODE2_IP="10.0.0.11"
NODE3_IP="10.0.0.12"
NODE1_HOSTNAME="appdva-vm-1"
NODE2_HOSTNAME="appdva-vm-2"
NODE3_HOSTNAME="appdva-vm-3"

# Network Settings
GATEWAY_IP="10.0.0.1"
DNS_SERVER="8.8.8.8"
CIDR_MASK="24"

# Deployment Profile
DEPLOYMENT_PROFILE="small"  # small, medium, large

# Services to Install
INSTALL_CORE=true
INSTALL_AIOPS=true
INSTALL_OTIS=true
INSTALL_ATD=false
INSTALL_UIL=false

# Certificate Configuration
USE_CUSTOM_CERTS=false
CERT_PATH=""
KEY_PATH=""

# License
LICENSE_FILE_PATH="/path/to/license.lic"

# Credentials (or use AWS Secrets Manager)
ADMIN_PASSWORD="changeme123"
DB_PASSWORD="dbpassword123"
```

### Template Processing
Use envsubst, j2cli, or custom script to substitute variables into templates.

---

## Phase 1: Pre-flight Checks Script

```bash
#!/bin/bash
# 00-preflight-check.sh

source lib/common.sh
source config/deployment.conf

echo "========================================="
echo "Pre-flight Deployment Checks"
echo "========================================="

ERRORS=0

# Check 1: AWS Resources
check_aws_resources() {
    echo "✓ Checking AWS resources..."
    
    # Verify instances are running
    for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
        if ! ping -c 1 -W 2 $node_ip &>/dev/null; then
            echo "❌ Cannot reach $node_ip"
            ((ERRORS++))
        else
            echo "  ✓ Node $node_ip is reachable"
        fi
    done
}

# Check 2: DNS Resolution
check_dns() {
    echo "✓ Checking DNS configuration..."
    
    REQUIRED_DOMAINS=(
        "${TENANT_NAME}.auth.${DNS_DOMAIN}"
        "${TENANT_NAME}-tnt-authn.${DNS_DOMAIN}"
        "controller.${DNS_DOMAIN}"
    )
    
    for domain in "${REQUIRED_DOMAINS[@]}"; do
        if ! nslookup $domain $DNS_SERVER &>/dev/null; then
            echo "❌ DNS record not found: $domain"
            ((ERRORS++))
        else
            echo "  ✓ DNS resolves: $domain"
        fi
    done
}

# Check 3: SSH Access
check_ssh_access() {
    echo "✓ Checking SSH access to nodes..."
    
    for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
        if ! ssh -o ConnectTimeout=5 -o BatchMode=yes appduser@$node_ip "exit" &>/dev/null; then
            echo "❌ Cannot SSH to $node_ip"
            echo "   Run: ssh-copy-id appduser@$node_ip"
            ((ERRORS++))
        else
            echo "  ✓ SSH access to $node_ip"
        fi
    done
}

# Check 4: Disk Space
check_disk_space() {
    echo "✓ Checking disk space on nodes..."
    
    for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
        os_space=$(ssh appduser@$node_ip "df -BG / | tail -1 | awk '{print \$4}' | sed 's/G//'")
        data_space=$(ssh appduser@$node_ip "df -BG /data | tail -1 | awk '{print \$4}' | sed 's/G//'")
        
        if [ "$os_space" -lt 50 ]; then
            echo "❌ Insufficient OS disk space on $node_ip: ${os_space}GB"
            ((ERRORS++))
        fi
        
        if [ "$data_space" -lt 100 ]; then
            echo "❌ Insufficient data disk space on $node_ip: ${data_space}GB"
            ((ERRORS++))
        fi
        
        echo "  ✓ $node_ip - OS: ${os_space}GB, Data: ${data_space}GB"
    done
}

# Check 5: Required Ports
check_ports() {
    echo "✓ Checking required ports..."
    
    PORTS=(22 443 8090 16443 19001)
    
    for port in "${PORTS[@]}"; do
        if nc -zv -w2 $NODE1_IP $port &>/dev/null; then
            echo "  ✓ Port $port accessible"
        else
            echo "⚠️  Port $port not accessible (may be opened after service install)"
        fi
    done
}

# Check 6: License File
check_license() {
    echo "✓ Checking license file..."
    
    if [ ! -f "$LICENSE_FILE_PATH" ]; then
        echo "❌ License file not found: $LICENSE_FILE_PATH"
        ((ERRORS++))
    else
        echo "  ✓ License file found"
    fi
}

# Check 7: Certificates (if custom)
check_certificates() {
    if [ "$USE_CUSTOM_CERTS" = "true" ]; then
        echo "✓ Checking custom certificates..."
        
        if [ ! -f "$CERT_PATH" ]; then
            echo "❌ Certificate not found: $CERT_PATH"
            ((ERRORS++))
        fi
        
        if [ ! -f "$KEY_PATH" ]; then
            echo "❌ Private key not found: $KEY_PATH"
            ((ERRORS++))
        fi
        
        # Validate certificate
        if openssl x509 -in "$CERT_PATH" -noout -checkend 86400 &>/dev/null; then
            echo "  ✓ Certificate is valid"
        else
            echo "⚠️  Certificate expires within 24 hours"
        fi
    fi
}

# Run all checks
check_aws_resources
check_dns
check_ssh_access
check_disk_space
check_ports
check_license
check_certificates

echo ""
echo "========================================="
if [ $ERRORS -eq 0 ]; then
    echo "✅ All pre-flight checks passed!"
    echo "========================================="
    exit 0
else
    echo "❌ $ERRORS error(s) found"
    echo "========================================="
    echo "Please fix errors before proceeding"
    exit 1
fi
```

---

## Phase 2: Bootstrap All VMs Script

```bash
#!/bin/bash
# 01-bootstrap-all-vms.sh

source lib/common.sh
source config/deployment.conf

echo "========================================="
echo "Bootstrapping All VMs"
echo "========================================="

bootstrap_node() {
    local node_ip=$1
    local node_hostname=$2
    local node_cidr="${node_ip}/${CIDR_MASK}"
    
    echo ""
    echo "🔧 Bootstrapping $node_hostname ($node_ip)..."
    
    # Create bootstrap script
    cat > /tmp/bootstrap-${node_hostname}.sh << EOF
#!/bin/bash
# Bootstrap script for ${node_hostname}

# Run appdctl host init with answers
echo "$node_hostname
$node_cidr
$GATEWAY_IP
$DNS_SERVER" | sudo appdctl host init

# Wait for bootstrap to complete
sleep 10

# Verify bootstrap
sudo appdctl show boot
EOF
    
    # Copy script to node
    scp /tmp/bootstrap-${node_hostname}.sh appduser@${node_ip}:/tmp/
    
    # Execute bootstrap
    ssh appduser@${node_ip} "chmod +x /tmp/bootstrap-${node_hostname}.sh && /tmp/bootstrap-${node_hostname}.sh"
    
    # Check result
    if [ $? -eq 0 ]; then
        echo "✅ Bootstrap completed for $node_hostname"
    else
        echo "❌ Bootstrap failed for $node_hostname"
        return 1
    fi
}

# Bootstrap all nodes in parallel
bootstrap_node $NODE1_IP $NODE1_HOSTNAME &
PID1=$!
bootstrap_node $NODE2_IP $NODE2_HOSTNAME &
PID2=$!
bootstrap_node $NODE3_IP $NODE3_HOSTNAME &
PID3=$!

# Wait for all to complete
wait $PID1
RESULT1=$?
wait $PID2
RESULT2=$?
wait $PID3
RESULT3=$?

echo ""
echo "========================================="
if [ $RESULT1 -eq 0 ] && [ $RESULT2 -eq 0 ] && [ $RESULT3 -eq 0 ]; then
    echo "✅ All nodes bootstrapped successfully!"
    echo "========================================="
    
    # Verify boot status on all nodes
    echo ""
    echo "Verifying boot status on all nodes..."
    for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
        echo ""
        echo "Node $node_ip:"
        ssh appduser@$node_ip "appdctl show boot"
    done
else
    echo "❌ Bootstrap failed on one or more nodes"
    echo "========================================="
    exit 1
fi
```

---

## Phase 3: Cluster Creation Script

```bash
#!/bin/bash
# 02-create-cluster.sh

source lib/common.sh
source config/deployment.conf

echo "========================================="
echo "Creating 3-Node Cluster"
echo "========================================="

# Verify all nodes are ready
echo "Verifying all nodes are ready..."
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    if ! ssh appduser@$node_ip "appdctl show boot | grep -q 'Succeeded'"; then
        echo "❌ Node $node_ip is not ready"
        exit 1
    fi
done
echo "✓ All nodes ready"

# Initialize cluster on primary node
echo ""
echo "Initializing cluster on primary node ($NODE1_IP)..."
ssh appduser@$NODE1_IP "appdctl cluster init $NODE2_IP $NODE3_IP"

if [ $? -ne 0 ]; then
    echo "❌ Cluster initialization failed"
    exit 1
fi

# Wait for cluster to form
echo "Waiting for cluster to form (30 seconds)..."
sleep 30

# Verify cluster status
echo ""
echo "Verifying cluster status..."
ssh appduser@$NODE1_IP "appdctl show cluster"
ssh appduser@$NODE1_IP "microk8s status"

# Check that all nodes show Running: true
RUNNING_NODES=$(ssh appduser@$NODE1_IP "appdctl show cluster" | grep -c "| true")
if [ "$RUNNING_NODES" -eq 3 ]; then
    echo ""
    echo "========================================="
    echo "✅ Cluster created successfully!"
    echo "   All 3 nodes are running"
    echo "========================================="
else
    echo ""
    echo "========================================="
    echo "⚠️  Warning: Not all nodes show as running"
    echo "   Expected: 3, Found: $RUNNING_NODES"
    echo "========================================="
    exit 1
fi
```

---

## Phase 4: Configuration Generation

```bash
#!/bin/bash
# 03-generate-configs.sh

source lib/common.sh
source config/deployment.conf

echo "========================================="
echo "Generating Configuration Files"
echo "========================================="

# Generate secure passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

MYSQL_ROOT_PASSWORD=$(generate_password)
MYSQL_CONTROLLER_PASSWORD=$(generate_password)
POSTGRES_PASSWORD=$(generate_password)
REDIS_PASSWORD=$(generate_password)

# Process globals.yaml template
echo "Generating globals.yaml..."
envsubst < templates/globals.yaml.template > /tmp/globals.yaml

# Process secrets.yaml template
echo "Generating secrets.yaml..."
export MYSQL_ROOT_PASSWORD MYSQL_CONTROLLER_PASSWORD POSTGRES_PASSWORD REDIS_PASSWORD
envsubst < templates/secrets.yaml.template > /tmp/secrets.yaml

# Validate YAML syntax
echo "Validating YAML syntax..."
if command -v yq &> /dev/null; then
    yq eval /tmp/globals.yaml > /dev/null && echo "  ✓ globals.yaml is valid"
    yq eval /tmp/secrets.yaml > /dev/null && echo "  ✓ secrets.yaml is valid"
else
    echo "  ⚠️  yq not installed, skipping validation"
fi

# Copy files to primary node
echo "Copying configuration files to primary node..."
scp /tmp/globals.yaml appduser@$NODE1_IP:/tmp/
scp /tmp/secrets.yaml appduser@$NODE1_IP:/tmp/
scp $LICENSE_FILE_PATH appduser@$NODE1_IP:/tmp/license.lic

# Move files to correct location on primary node
ssh appduser@$NODE1_IP << 'EOF'
sudo mv /tmp/globals.yaml /var/appd/config/globals.yaml.gotmpl
sudo mv /tmp/secrets.yaml /var/appd/config/secrets.yaml
sudo mv /tmp/license.lic /var/appd/config/license.lic
sudo chown appduser:appduser /var/appd/config/*
sudo chmod 600 /var/appd/config/secrets.yaml
EOF

echo "✅ Configuration files generated and deployed"

# Save passwords for reference
cat > /tmp/credentials.txt << EOF
AppDynamics Deployment Credentials
Generated: $(date)

MySQL Root Password: $MYSQL_ROOT_PASSWORD
MySQL Controller Password: $MYSQL_CONTROLLER_PASSWORD
PostgreSQL Password: $POSTGRES_PASSWORD
Redis Password: $REDIS_PASSWORD

KEEP THIS FILE SECURE!
EOF

echo ""
echo "⚠️  Important: Credentials saved to /tmp/credentials.txt"
echo "   Please store securely and delete this file"
```

---

## Implementation Priority

### Week 1: Critical Path
1. ✅ Create pre-flight check script
2. ✅ Create VM bootstrap automation
3. ✅ Create cluster formation script
4. ⏳ Create configuration templates
5. ⏳ Test end-to-end

### Week 2: Service Installation
1. Create service installation automation
2. Add progress monitoring
3. Add health checks
4. Add rollback capability

### Week 3: Polish & Documentation
1. Add comprehensive error handling
2. Create user documentation
3. Add validation scripts
4. Create troubleshooting guide

---

## Next Steps

1. **Choose Approach**: Ansible (more robust) or Bash (simpler)
2. **Create Configuration Template**: Based on your specific needs
3. **Implement Core Scripts**: Pre-flight, bootstrap, cluster, install
4. **Test in Non-Prod**: Validate with test deployment
5. **Iterate**: Fix issues found during testing

Would you like me to start implementing the full automation scripts?
