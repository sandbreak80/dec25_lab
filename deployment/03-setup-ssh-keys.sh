#!/bin/bash
# Setup SSH keys for passwordless access to VMs
# This must be run AFTER appd-change-password.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Setup SSH Keys for Passwordless Access                 ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [--password PASSWORD]

Arguments:
    --team, -t NUMBER       Your team number (1-5)
    --password, -p PASSWORD appduser password (default: AppDynamics123!)
    --help, -h              Show this help

Examples:
    $0 --team 1
    $0 --team 1 --password MySecurePass123!

This script will:
  1. ✓ Generate SSH key pair on your laptop
  2. ✓ Copy public key to all 3 VMs
  3. ✓ Enable passwordless SSH access
  4. ✓ Update all scripts to use keys

Prerequisites:
  - VMs must be deployed
  - appduser password must be changed (run appd-change-password.sh first)

After this script:
  - All SSH will be passwordless
  - All automation scripts will work seamlessly
  - Better student experience!

EOF
    exit 1
}

TEAM_NUMBER=""
PASSWORD="AppDynamics123!"

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --password|-p) PASSWORD="$2"; shift 2 ;;
        --help|-h) show_usage ;;
        *) log_error "Unknown parameter: $1"; show_usage ;;
    esac
done

if [[ -z "$TEAM_NUMBER" ]] || ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
    log_error "Team number must be 1-5"
    show_usage
fi

load_team_config "$TEAM_NUMBER"
check_aws_cli

# Detect correct password if not provided as argument
if [ "$PASSWORD" = "AppDynamics123!" ]; then
    # Default was not changed by --password argument, so auto-detect
    if [ -f "state/team${TEAM_NUMBER}/password-changed.flag" ]; then
        PASSWORD="AppDynamics123!"
    else
        PASSWORD="changeme"
    fi
fi

# Check for expect
if ! command -v expect &> /dev/null; then
    log_error "expect is not installed"
    echo ""
    echo "Install expect first:"
    echo "  macOS: brew install expect"
    echo "  Linux: sudo apt-get install expect"
    exit 1
fi

echo ""
log_info "Setting up SSH keys for Team ${TEAM_NUMBER}..."
echo ""

# Get VM IPs
VM1_IP=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt" 2>/dev/null)
VM2_IP=$(cat "state/team${TEAM_NUMBER}/vm2-public-ip.txt" 2>/dev/null)
VM3_IP=$(cat "state/team${TEAM_NUMBER}/vm3-public-ip.txt" 2>/dev/null)

if [[ -z "$VM1_IP" ]] || [[ -z "$VM2_IP" ]] || [[ -z "$VM3_IP" ]]; then
    log_error "VM IPs not found. Has infrastructure been deployed?"
    exit 1
fi

# Define key path
KEY_NAME="appd-team${TEAM_NUMBER}-key"
KEY_PATH="${HOME}/.ssh/${KEY_NAME}"

# Step 1: Generate SSH key if it doesn't exist
if [[ -f "${KEY_PATH}" ]]; then
    log_warning "SSH key already exists: ${KEY_PATH}"
    
    # Check if running non-interactively (e.g., from full-deploy.sh)
    if [ -t 0 ]; then
        # Interactive mode - ask user
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Using existing key"
        else
            log_info "Generating new SSH key pair..."
            rm -f "${KEY_PATH}" "${KEY_PATH}.pub"
            ssh-keygen -t ed25519 -f "${KEY_PATH}" -N "" -C "appd-lab-team${TEAM_NUMBER}"
        fi
    else
        # Non-interactive mode - overwrite automatically
        log_info "Non-interactive mode: Overwriting existing key..."
        rm -f "${KEY_PATH}" "${KEY_PATH}.pub"
        ssh-keygen -t ed25519 -f "${KEY_PATH}" -N "" -C "appd-lab-team${TEAM_NUMBER}"
    fi
    log_success "SSH key ready: ${KEY_PATH}"
else
    log_info "Generating SSH key pair..."
    ssh-keygen -t ed25519 -f "${KEY_PATH}" -N "" -C "appd-lab-team${TEAM_NUMBER}"
    log_success "SSH key generated: ${KEY_PATH}"
fi

echo ""
log_info "SSH key details:"
echo "  Private key: ${KEY_PATH}"
echo "  Public key:  ${KEY_PATH}.pub"
echo ""

# Function to copy key to a VM
copy_key_to_vm() {
    local VM_NUM=$1
    local VM_IP=$2
    
    log_info "[$VM_NUM/3] Copying SSH key to VM${VM_NUM}: $VM_IP"
    
    # Wait for SSH to be ready (retry up to 3 times)
    for attempt in 1 2 3; do
        if [ $attempt -gt 1 ]; then
            log_warning "Retry $attempt/3..."
            sleep 5
        fi
        
        # Use expect to handle password prompt with ssh-copy-id
        expect << EOF_EXPECT 2>&1 | sed 's/^/    /'
set timeout 30
log_user 0

spawn ssh-copy-id -i ${KEY_PATH}.pub -o StrictHostKeyChecking=no appduser@${VM_IP}

expect {
    "password:" {
        send "${PASSWORD}\r"
        expect {
            "added" {
                puts "✅ SSH key copied successfully"
                exit 0
            }
            "All keys were skipped" {
                puts "✅ SSH key already present"
                exit 0
            }
            timeout {
                puts "❌ Timeout waiting for confirmation"
                exit 1
            }
        }
    }
    "All keys were skipped" {
        puts "✅ SSH key already present"
        exit 0
    }
    timeout {
        puts "❌ Timeout waiting for password prompt"
        exit 1
    }
}

expect eof
EOF_EXPECT
        
        if [ $? -eq 0 ]; then
            log_success "VM${VM_NUM} SSH key installed!"
            return 0
        fi
    done
    
    log_error "Failed to copy SSH key to VM${VM_NUM} after 3 attempts"
    exit 1
    
    echo ""
}

# Step 2: Copy SSH key to all VMs
echo ""
log_info "Copying SSH key to all VMs..."
echo ""

copy_key_to_vm 1 "$VM1_IP"
copy_key_to_vm 2 "$VM2_IP"
copy_key_to_vm 3 "$VM3_IP"

# Step 3: Test SSH access
echo ""
log_info "Testing passwordless SSH access..."
echo ""

test_ssh() {
    local VM_NUM=$1
    local VM_IP=$2
    
    log_info "Testing VM${VM_NUM}: $VM_IP"
    
    if ssh -i "${KEY_PATH}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR appduser@${VM_IP} "echo 'SSH test successful'" &>/dev/null; then
        log_success "VM${VM_NUM} SSH: OK (passwordless)"
    else
        log_error "VM${VM_NUM} SSH: FAILED"
        return 1
    fi
}

test_ssh 1 "$VM1_IP"
test_ssh 2 "$VM2_IP"
test_ssh 3 "$VM3_IP"

# Step 4: Save key path to team state
echo ""
log_info "Saving SSH key configuration..."
mkdir -p "state/team${TEAM_NUMBER}"
echo "${KEY_PATH}" > "state/team${TEAM_NUMBER}/ssh-key-path.txt"
log_success "SSH key path saved to state"

# Step 5: Optional - Create SSH config entry
echo ""
log_info "Creating SSH config entries (optional)..."

SSH_CONFIG="${HOME}/.ssh/config"
if grep -q "# AppD Team ${TEAM_NUMBER}" "${SSH_CONFIG}" 2>/dev/null; then
    log_warning "SSH config entries already exist"
else
    cat >> "${SSH_CONFIG}" << EOF_CONFIG

# AppD Team ${TEAM_NUMBER} - Auto-generated by setup-ssh-keys.sh
Host appd-team${TEAM_NUMBER}-vm1
    HostName ${VM1_IP}
    User appduser
    IdentityFile ${KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host appd-team${TEAM_NUMBER}-vm2
    HostName ${VM2_IP}
    User appduser
    IdentityFile ${KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host appd-team${TEAM_NUMBER}-vm3
    HostName ${VM3_IP}
    User appduser
    IdentityFile ${KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF_CONFIG
    
    log_success "SSH config updated: ${SSH_CONFIG}"
fi

echo ""
log_success "SSH key setup complete!"
echo ""

cat << EOF
╔══════════════════════════════════════════════════════════╗
║  SSH Keys Configured Successfully!                      ║
╚══════════════════════════════════════════════════════════╝

✅ SSH key generated: ${KEY_PATH}
✅ Public key copied to all 3 VMs
✅ Passwordless SSH enabled

You can now SSH to your VMs:
  
  Using helper scripts:
    ./scripts/ssh-vm1.sh --team ${TEAM_NUMBER}
    ./scripts/ssh-vm2.sh --team ${TEAM_NUMBER}
    ./scripts/ssh-vm3.sh --team ${TEAM_NUMBER}
  
  Using SSH config shortcuts:
    ssh appd-team${TEAM_NUMBER}-vm1
    ssh appd-team${TEAM_NUMBER}-vm2
    ssh appd-team${TEAM_NUMBER}-vm3
  
  Using direct SSH:
    ssh -i ${KEY_PATH} appduser@${VM1_IP}
    ssh -i ${KEY_PATH} appduser@${VM2_IP}
    ssh -i ${KEY_PATH} appduser@${VM3_IP}

Next Steps:
  1. Test SSH access (no password needed!):
     ./scripts/ssh-vm1.sh --team ${TEAM_NUMBER}
  
  2. Bootstrap VMs:
     ./appd-bootstrap-vms.sh --team ${TEAM_NUMBER}
  
  3. Create cluster:
     ./appd-create-cluster.sh --team ${TEAM_NUMBER}

All automation scripts will now work passwordless! 🎉

EOF
