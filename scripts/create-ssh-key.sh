#!/bin/bash
# Create SSH Key Pair for Lab
# Students run this FIRST before deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Parse arguments
show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Create SSH Key Pair for AppDynamics Lab               ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER

Arguments:
    --team, -t NUMBER    Your team number (1-5)
    --help, -h           Show this help

Example:
    $0 --team 1

This script will:
  1. ✓ Create a new AWS EC2 key pair for your team
  2. ✓ Download the private key to ~/.ssh/
  3. ✓ Set proper permissions (400)
  4. ✓ Update your team config to use this key
  5. ✓ Display SSH connection command

EOF
    exit 1
}

TEAM_NUMBER=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
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

log_info "Creating SSH key pair for Team ${TEAM_NUMBER}..."

# Key name
KEY_NAME="appd-lab-team${TEAM_NUMBER}-key"
KEY_FILE="${HOME}/.ssh/${KEY_NAME}.pem"

# Check if key already exists in AWS
EXISTING_KEY=$(aws ec2 describe-key-pairs --key-names "$KEY_NAME" --query 'KeyPairs[0].KeyName' --output text 2>/dev/null || echo "")

if [[ -n "$EXISTING_KEY" ]]; then
    log_warning "Key pair '$KEY_NAME' already exists in AWS"
    echo ""
    read -p "Delete and recreate? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        log_info "Using existing key pair"
        
        # Check if local key file exists
        if [[ ! -f "$KEY_FILE" ]]; then
            log_error "Key exists in AWS but private key file not found: $KEY_FILE"
            echo ""
            echo "Options:"
            echo "  1. Delete the AWS key and run this script again"
            echo "  2. If you have the key file elsewhere, copy it to: $KEY_FILE"
            echo ""
            echo "To delete AWS key:"
            echo "  aws ec2 delete-key-pair --key-name $KEY_NAME"
            exit 1
        fi
        
        log_success "Key file found: $KEY_FILE"
    else
        log_info "Deleting existing key pair..."
        aws ec2 delete-key-pair --key-name "$KEY_NAME"
        log_success "Key pair deleted"
    fi
fi

# Create new key pair if needed
if [[ ! -f "$KEY_FILE" ]] || [[ "$CONFIRM" == "yes" ]]; then
    log_info "Creating new key pair in AWS: $KEY_NAME"
    
    # Create directory if needed
    mkdir -p "${HOME}/.ssh"
    
    # Create key pair and save private key
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query 'KeyMaterial' \
        --output text > "$KEY_FILE"
    
    # Set proper permissions
    chmod 400 "$KEY_FILE"
    
    log_success "Key pair created: $KEY_NAME"
    log_success "Private key saved: $KEY_FILE"
fi

# Verify key file
if [[ ! -f "$KEY_FILE" ]]; then
    log_error "Failed to create key file"
    exit 1
fi

# Update team config with key name
CONFIG_FILE="${SCRIPT_DIR}/config/team${TEAM_NUMBER}.cfg"
if grep -q "^VM_SSH_KEY=" "$CONFIG_FILE"; then
    # Update existing line
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^VM_SSH_KEY=.*|VM_SSH_KEY=\"$KEY_NAME\"|" "$CONFIG_FILE"
    else
        sed -i "s|^VM_SSH_KEY=.*|VM_SSH_KEY=\"$KEY_NAME\"|" "$CONFIG_FILE"
    fi
    log_success "Updated config: $CONFIG_FILE"
else
    log_warning "VM_SSH_KEY not found in config file - you may need to add it manually"
fi

# Display summary
echo ""
log_success "SSH key setup complete!"
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  SSH Key Configuration Summary                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Key Name:     $KEY_NAME"
echo "  Key File:     $KEY_FILE"
echo "  Permissions:  $(ls -l "$KEY_FILE" | awk '{print $1}')"
echo "  Team:         $TEAM_NUMBER"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🚀 NEXT STEPS:"
echo ""
echo "1. Deploy your infrastructure:"
echo "   ./lab-deploy.sh --team $TEAM_NUMBER"
echo ""
echo "2. After deployment, SSH to your VMs:"
echo "   ssh -i $KEY_FILE appduser@<VM-IP>"
echo ""
echo "3. Or use the helper script:"
echo "   ./scripts/ssh-vm1.sh --team $TEAM_NUMBER"
echo ""
echo "Note: Keep this key file secure! Don't commit it to git."
echo ""
