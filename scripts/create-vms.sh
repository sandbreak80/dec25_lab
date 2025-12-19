#!/bin/bash
# Create EC2 Instances (3 VMs) - Vendor-Compatible Approach
# Creates ENI first, then EIP, then instance (for better reliability)
# Internal script - called by lab-deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"
check_aws_cli

log_info "Deploying 3 EC2 instances for Team ${TEAM_NUMBER}..."
echo ""
log_warning "Using vendor-compatible approach:"
echo "  1. Create ENI (Elastic Network Interface)"
echo "  2. Allocate EIP (Elastic IP)"
echo "  3. Associate EIP to ENI"
echo "  4. Launch instance with ENI"
echo ""

# Get resources
log_info "Loading resource IDs from previous phases..."
VPC_ID=$(load_resource_id vpc "$TEAM_NUMBER")
SUBNET_ID=$(load_resource_id subnet "$TEAM_NUMBER")
VM_SG_ID=$(load_resource_id vm-sg "$TEAM_NUMBER")

# Validate required resources exist
if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    log_error "VPC not found. Did Phase 1 (network creation) complete successfully?"
    log_info "Expected state file: state/team${TEAM_NUMBER}/vpc.id"
    log_info "Try running: ./deployment/01-deploy.sh --team ${TEAM_NUMBER}"
    exit 1
fi

if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" == "None" ]; then
    log_error "Subnet not found. Did Phase 1 (network creation) complete successfully?"
    log_info "Expected state file: state/team${TEAM_NUMBER}/subnet.id"
    log_info "Try running: ./deployment/01-deploy.sh --team ${TEAM_NUMBER}"
    exit 1
fi

if [ -z "$VM_SG_ID" ] || [ "$VM_SG_ID" == "None" ]; then
    log_error "Security Group not found. Did Phase 2 (security group creation) complete successfully?"
    log_info "Expected state file: state/team${TEAM_NUMBER}/vm-sg.id"
    log_info "Try running: ./deployment/01-deploy.sh --team ${TEAM_NUMBER}"
    exit 1
fi

log_success "All prerequisite resources found!"

# Get AMI ID (from global config)
log_info "Loading AMI ID from global configuration..."
if [ -f "${SCRIPT_DIR}/config/global.cfg" ]; then
    source "${SCRIPT_DIR}/config/global.cfg"
    AMI_ID="$APPD_AMI_ID"
else
    log_error "Global configuration not found: config/global.cfg"
    exit 1
fi

if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
    log_error "AMI ID not configured in config/global.cfg"
    log_info "Update APPD_AMI_ID in config/global.cfg"
    log_info "Contact instructor if you don't have this value."
    exit 1
fi

log_info "Using AMI: $AMI_ID"
log_info "VPC: $VPC_ID"
log_info "Subnet: $SUBNET_ID"
log_info "Security Group: $VM_SG_ID"
echo ""

# Create 3 VMs using vendor approach
for i in 1 2 3; do
    VM_NAME="team${TEAM_NUMBER}-vm-${i}"
    
    log_info "[$i/3] Creating $VM_NAME..."
    echo ""
    
    # Check if already exists
    log_info "  Checking if VM already exists in AWS..."
    INSTANCE_ID=$(get_resource_id instance "$VM_NAME")
    CHECK_RESULT=$?
    
    if [ $CHECK_RESULT -ne 0 ]; then
        log_error "Failed to check if instance exists. See error above."
        log_info "This could be due to:"
        log_info "  - AWS CLI not configured correctly"
        log_info "  - Invalid AWS credentials"
        log_info "  - Network connectivity issues"
        log_info "  - Wrong AWS region configured"
        exit 1
    fi
    
    if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
        
        # Step 1: Create cloud-init user-data (vendor approach)
        cat > /tmp/user-data-vm${i}.txt <<'USER_DATA_EOF'
#cloud-config
ssh_pwauth: True
appdos:
  bootstrap:
    netplan:
      dhcp4: true
      dhcp6: false
USER_DATA_EOF
        
        log_info "  [1/5] Creating Elastic Network Interface..."
        ENI_OUTPUT=$(aws ec2 create-network-interface \
            --subnet-id "$SUBNET_ID" \
            --description "Team ${TEAM_NUMBER} VM${i} Network Interface" \
            --groups "$VM_SG_ID" \
            --tag-specifications "ResourceType=network-interface,Tags=[{Key=Name,Value=${VM_NAME}-eni},{Key=Team,Value=team${TEAM_NUMBER}}]" \
            --query 'NetworkInterface.NetworkInterfaceId' \
            --output text 2>&1)
        
        ENI_ID=$(echo "$ENI_OUTPUT" | tail -1)
        
        if [ -z "$ENI_ID" ] || [ "$ENI_ID" == "None" ] || echo "$ENI_ID" | grep -q "UnauthorizedOperation"; then
            log_error "Failed to create ENI"
            if echo "$ENI_OUTPUT" | grep -q "UnauthorizedOperation"; then
                log_error "IAM Permission Error: User 'lab-student' is not authorized to perform: ec2:CreateNetworkInterface"
                log_info "Contact your instructor to update IAM policy with the latest permissions."
            else
                echo "Error details: $ENI_OUTPUT"
            fi
            exit 1
        fi
        log_success "  ENI created: $ENI_ID"
        
        # Step 2: Allocate Elastic IP
        log_info "  [2/5] Allocating Elastic IP..."
        ALLOCATION_ID=$(aws ec2 allocate-address \
            --domain vpc \
            --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${VM_NAME}-eip},{Key=Team,Value=team${TEAM_NUMBER}}]" \
            --query 'AllocationId' \
            --output text)
        
        if [ -z "$ALLOCATION_ID" ] || [ "$ALLOCATION_ID" == "None" ]; then
            log_error "Failed to allocate EIP"
            # Clean up ENI
            aws ec2 delete-network-interface --network-interface-id "$ENI_ID" 2>/dev/null || true
            exit 1
        fi
        log_success "  EIP allocated: $ALLOCATION_ID"
        
        # Step 3: Associate EIP to ENI
        log_info "  [3/5] Associating EIP to ENI..."
        ASSOCIATION_ID=$(aws ec2 associate-address \
            --allocation-id "$ALLOCATION_ID" \
            --network-interface-id "$ENI_ID" \
            --query 'AssociationId' \
            --output text)
        
        if [ -z "$ASSOCIATION_ID" ] || [ "$ASSOCIATION_ID" == "None" ]; then
            log_error "Failed to associate EIP"
            # Clean up
            aws ec2 release-address --allocation-id "$ALLOCATION_ID" 2>/dev/null || true
            aws ec2 delete-network-interface --network-interface-id "$ENI_ID" 2>/dev/null || true
            exit 1
        fi
        log_success "  EIP associated: $ASSOCIATION_ID"
        
        # Step 4: Launch instance with ENI (vendor approach)
        log_info "  [4/5] Launching EC2 instance..."
        
        # CRITICAL: Use vendor disk configuration
        # - /dev/sda1: OS disk (delete on termination)
        # - /dev/sdb: Data disk (PRESERVE on termination!)
        INSTANCE_OUTPUT=$(aws ec2 run-instances \
            --image-id "$AMI_ID" \
            --instance-type "$VM_TYPE" \
            --network-interfaces "[{\"NetworkInterfaceId\":\"${ENI_ID}\",\"DeviceIndex\":0}]" \
            --block-device-mappings \
                "DeviceName=/dev/sda1,Ebs={VolumeSize=${VM_OS_DISK},VolumeType=gp3,DeleteOnTermination=true}" \
                "DeviceName=/dev/sdb,Ebs={VolumeSize=${VM_DATA_DISK},VolumeType=gp3,DeleteOnTermination=false}" \
            --user-data file:///tmp/user-data-vm${i}.txt \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$VM_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" \
            --no-cli-pager \
            --query 'Instances[0].InstanceId' \
            --output text 2>&1)
        
        INSTANCE_ID=$(echo "$INSTANCE_OUTPUT" | tail -1)
        
        # Clean up user-data file
        rm -f /tmp/user-data-vm${i}.txt
        
        if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ] || echo "$INSTANCE_ID" | grep -q "UnauthorizedOperation"; then
            log_error "Failed to launch instance"
            
            if echo "$INSTANCE_OUTPUT" | grep -q "UnauthorizedOperation"; then
                log_error "IAM Permission Error: User 'lab-student' is not authorized to perform: ec2:RunInstances"
                log_info ""
                log_info "This error occurs when IAM policy is missing required RunInstances permissions."
                log_info "RunInstances requires permissions for multiple resource types:"
                log_info "  - ec2:instance/*"
                log_info "  - ec2:volume/*"
                log_info "  - ec2:network-interface/*"
                log_info "  - ec2:subnet/*"
                log_info "  - ec2:security-group/*"
                log_info "  - ec2:image/*"
                log_info ""
                log_info "📧 Contact your instructor with this error message."
                log_info "📄 Instructor: Update IAM policy using docs/iam-student-policy.json"
            else
                echo "Error details: $INSTANCE_OUTPUT"
            fi
            
            # Clean up
            log_info "Cleaning up resources..."
            aws ec2 disassociate-address --association-id "$ASSOCIATION_ID" 2>/dev/null || true
            aws ec2 release-address --allocation-id "$ALLOCATION_ID" 2>/dev/null || true
            aws ec2 delete-network-interface --network-interface-id "$ENI_ID" 2>/dev/null || true
            exit 1
        fi
        
        log_success "  Instance launched: $INSTANCE_ID"
        
    else
        log_info "  Instance already exists: $INSTANCE_ID"
    fi
    
    save_resource_id "vm${i}" "$INSTANCE_ID" "$TEAM_NUMBER"
    save_resource_id "vm${i}-eni" "$ENI_ID" "$TEAM_NUMBER" 2>/dev/null || true
    save_resource_id "vm${i}-eip" "$ALLOCATION_ID" "$TEAM_NUMBER" 2>/dev/null || true
    
    # Step 5: Wait for instance and get IPs
    log_info "  [5/5] Waiting for instance to start..."
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
    
    # Get public IP (from EIP)
    PUBLIC_IP=$(aws ec2 describe-addresses \
        --allocation-ids "$ALLOCATION_ID" \
        --query 'Addresses[0].PublicIp' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$PUBLIC_IP" ]; then
        # Fallback: get from instance
        PUBLIC_IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)
    fi
    
    echo "$PUBLIC_IP" > "state/team${TEAM_NUMBER}/vm${i}-public-ip.txt"
    
    # Get private IP
    PRIVATE_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)
    
    echo "$PRIVATE_IP" > "state/team${TEAM_NUMBER}/vm${i}-private-ip.txt"
    
    log_success "  $VM_NAME ready!"
    echo "    Public IP:  $PUBLIC_IP (EIP - persists if instance stopped)"
    echo "    Private IP: $PRIVATE_IP"
    echo "    Data Disk:  /dev/sdb (500GB, preserved on termination)"
    echo ""
done

log_success "All 3 VMs deployed!"
echo ""

cat << EOF
╔══════════════════════════════════════════════════════════╗
║  VM Deployment Summary                                  ║
╚══════════════════════════════════════════════════════════╝

Instance Type: $VM_TYPE (16 vCPU, 64GB RAM)
OS Disk: ${VM_OS_DISK}GB (gp3, delete on termination)
Data Disk: ${VM_DATA_DISK}GB (gp3, ✅ PRESERVED on termination)

VM1: $(cat state/team${TEAM_NUMBER}/vm1-public-ip.txt) (public) / $(cat state/team${TEAM_NUMBER}/vm1-private-ip.txt) (private)
VM2: $(cat state/team${TEAM_NUMBER}/vm2-public-ip.txt) (public) / $(cat state/team${TEAM_NUMBER}/vm2-private-ip.txt) (private)
VM3: $(cat state/team${TEAM_NUMBER}/vm3-public-ip.txt) (public) / $(cat state/team${TEAM_NUMBER}/vm3-private-ip.txt) (private)

✅ ENI created for each VM (better network control)
✅ EIP allocated and associated (persistent public IPs)
✅ Data disk preserved (survives instance termination)
✅ Password SSH enabled (appduser / changeme)

EOF

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
