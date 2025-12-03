#!/bin/bash
# Create EC2 Instances (3 VMs)
# Internal script - called by lab-deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"
check_aws_cli

log_info "Deploying 3 EC2 instances for Team ${TEAM_NUMBER}..."

# Get resources
VPC_ID=$(load_resource_id vpc "$TEAM_NUMBER")
SUBNET_ID=$(load_resource_id subnet "$TEAM_NUMBER")
VM_SG_ID=$(load_resource_id vm-sg "$TEAM_NUMBER")

# Get AMI ID (shared across all teams)
AMI_ID=$(cat "state/shared/ami.id" 2>/dev/null)
if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
    log_error "AMI not found. Contact instructor."
    exit 1
fi

# Create 3 VMs
for i in 1 2 3; do
    VM_NAME="team${TEAM_NUMBER}-vm-${i}"
    
    log_info "[$i/3] Creating $VM_NAME..."
    
    # Check if already exists
    INSTANCE_ID=$(get_resource_id instance "$VM_NAME")
    
    if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
        # Create cloud-init user-data to enable password SSH (vendor approach)
        cat > /tmp/user-data-vm${i}.txt <<'USER_DATA_EOF'
#cloud-config
ssh_pwauth: True
appdos:
  bootstrap:
    netplan:
      dhcp4: true
      dhcp6: false
USER_DATA_EOF
        
        # Create instance with user-data (enables password SSH for appduser)
        INSTANCE_ID=$(aws ec2 run-instances \
            --image-id "$AMI_ID" \
            --instance-type "$VM_TYPE" \
            --subnet-id "$SUBNET_ID" \
            --security-group-ids "$VM_SG_ID" \
            --user-data file:///tmp/user-data-vm${i}.txt \
            --block-device-mappings \
                "DeviceName=/dev/sda1,Ebs={VolumeSize=${VM_OS_DISK},VolumeType=gp3,DeleteOnTermination=true}" \
                "DeviceName=/dev/sdf,Ebs={VolumeSize=${VM_DATA_DISK},VolumeType=gp3,DeleteOnTermination=true}" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$VM_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" \
            --query 'Instances[0].InstanceId' --output text)
        
        # Clean up user-data file
        rm -f /tmp/user-data-vm${i}.txt
        
        log_success "Instance created: $INSTANCE_ID"
    else
        log_info "Instance already exists: $INSTANCE_ID"
    fi
    
    save_resource_id "vm${i}" "$INSTANCE_ID" "$TEAM_NUMBER"
    
    # Wait for instance to be running
    log_info "Waiting for instance to start..."
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
    
    # Get public IP
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    echo "$PUBLIC_IP" > "state/team${TEAM_NUMBER}/vm${i}-public-ip.txt"
    
    # Get private IP
    PRIVATE_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)
    
    echo "$PRIVATE_IP" > "state/team${TEAM_NUMBER}/vm${i}-private-ip.txt"
    
    log_success "$VM_NAME ready: $PUBLIC_IP (public) / $PRIVATE_IP (private)"
done

log_success "All 3 VMs deployed!"

# Save summary
cat > "state/team${TEAM_NUMBER}/vm-summary.txt" << EOF
VM1 Public:  $(cat state/team${TEAM_NUMBER}/vm1-public-ip.txt)
VM1 Private: $(cat state/team${TEAM_NUMBER}/vm1-private-ip.txt)
VM2 Public:  $(cat state/team${TEAM_NUMBER}/vm2-public-ip.txt)
VM2 Private: $(cat state/team${TEAM_NUMBER}/vm2-private-ip.txt)
VM3 Public:  $(cat state/team${TEAM_NUMBER}/vm3-public-ip.txt)
VM3 Private: $(cat state/team${TEAM_NUMBER}/vm3-private-ip.txt)
EOF

log_info "VM summary saved to: state/team${TEAM_NUMBER}/vm-summary.txt"
