#!/bin/bash
# Common functions and utilities for multi-team lab scripts

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Parse team number from command line
parse_team_number() {
    TEAM_NUMBER=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --team)
                TEAM_NUMBER="$2"
                shift 2
                ;;
            -t)
                TEAM_NUMBER="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown parameter: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [ -z "$TEAM_NUMBER" ]; then
        log_error "Team number is required"
        show_usage
        exit 1
    fi
    
    # Validate team number
    if ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
        log_error "Team number must be between 1 and 5"
        exit 1
    fi
    
    echo "$TEAM_NUMBER"
}

# Load team configuration
load_team_config() {
    local team_num=$1
    local config_file="config/team${team_num}.cfg"
    
    if [ ! -f "$config_file" ]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    log_info "Loading configuration for Team ${team_num}..."
    source "$config_file"
    
    # Set AWS profile
    export AWS_PROFILE="${AWS_PROFILE}"
    
    log_success "Configuration loaded: Team ${team_num}"
    log_info "VPC: ${VPC_NAME} (${VPC_CIDR})"
    log_info "Domain: ${FULL_DOMAIN}"
}

# Check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        log_info "Install: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured or credentials are invalid"
        log_info "Run: aws configure --profile ${AWS_PROFILE}"
        exit 1
    fi
    
    log_success "AWS CLI configured"
}

# Check if a resource exists
resource_exists() {
    local resource_type=$1
    local resource_name=$2
    
    case $resource_type in
        vpc)
            aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$resource_name" --query 'Vpcs[0].VpcId' --output text 2>/dev/null | grep -v "None" &> /dev/null
            ;;
        subnet)
            aws ec2 describe-subnets --filters "Name=tag:Name,Values=$resource_name" --query 'Subnets[0].SubnetId' --output text 2>/dev/null | grep -v "None" &> /dev/null
            ;;
        sg)
            aws ec2 describe-security-groups --filters "Name=group-name,Values=$resource_name" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null | grep -v "None" &> /dev/null
            ;;
        instance)
            aws ec2 describe-instances --filters "Name=tag:Name,Values=$resource_name" "Name=instance-state-name,Values=running,pending" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null | grep -v "None" &> /dev/null
            ;;
        alb)
            aws elbv2 describe-load-balancers --names "$resource_name" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null | grep -v "None" &> /dev/null
            ;;
        tg)
            aws elbv2 describe-target-groups --names "$resource_name" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null | grep -v "None" &> /dev/null
            ;;
        *)
            log_error "Unknown resource type: $resource_type"
            return 1
            ;;
    esac
}

# Get resource ID
get_resource_id() {
    local resource_type=$1
    local resource_name=$2
    
    case $resource_type in
        vpc)
            aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$resource_name" --query 'Vpcs[0].VpcId' --output text 2>/dev/null
            ;;
        subnet)
            aws ec2 describe-subnets --filters "Name=tag:Name,Values=$resource_name" --query 'Subnets[0].SubnetId' --output text 2>/dev/null
            ;;
        sg)
            aws ec2 describe-security-groups --filters "Name=group-name,Values=$resource_name" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null
            ;;
        igw)
            aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=$resource_name" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null
            ;;
        rt)
            aws ec2 describe-route-tables --filters "Name=tag:Name,Values=$resource_name" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null
            ;;
        instance)
            aws ec2 describe-instances --filters "Name=tag:Name,Values=$resource_name" "Name=instance-state-name,Values=running,pending" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null
            ;;
        alb)
            aws elbv2 describe-load-balancers --names "$resource_name" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null
            ;;
        tg)
            aws elbv2 describe-target-groups --names "$resource_name" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null
            ;;
        *)
            log_error "Unknown resource type: $resource_type"
            return 1
            ;;
    esac
}

# Save resource ID to file
save_resource_id() {
    local resource_type=$1
    local resource_id=$2
    local team_num=$3
    
    local state_dir="state/team${team_num}"
    mkdir -p "$state_dir"
    
    echo "$resource_id" > "${state_dir}/${resource_type}.id"
}

# Load resource ID from file
load_resource_id() {
    local resource_type=$1
    local team_num=$2
    
    local state_file="state/team${team_num}/${resource_type}.id"
    
    if [ -f "$state_file" ]; then
        cat "$state_file"
    fi
}

# Mark step as completed
mark_step_complete() {
    local step_name=$1
    local team_num=$2
    
    local progress_file="state/team${team_num}/progress.txt"
    mkdir -p "state/team${team_num}"
    
    if ! grep -q "^${step_name}$" "$progress_file" 2>/dev/null; then
        echo "$step_name" >> "$progress_file"
        log_success "Step completed: $step_name"
    fi
}

# Check if step is completed
is_step_complete() {
    local step_name=$1
    local team_num=$2
    
    local progress_file="state/team${team_num}/progress.txt"
    
    if [ -f "$progress_file" ]; then
        grep -q "^${step_name}$" "$progress_file" 2>/dev/null
    else
        return 1
    fi
}

# Confirm action
confirm_action() {
    local message=$1
    
    if [ "${SKIP_CONFIRMATIONS}" = "true" ]; then
        return 0
    fi
    
    echo -e "${YELLOW}${message}${NC}"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Action cancelled"
        exit 1
    fi
}

# Format AWS tags for CLI
format_tags() {
    local team_num=$1
    
    echo "ResourceType=instance,Tags=["
    echo "{Key=Project,Value=AppDynamics-Lab},"
    echo "{Key=Team,Value=team${team_num}},"
    echo "{Key=Environment,Value=lab},"
    echo "{Key=Owner,Value=${INSTRUCTOR_EMAIL}},"
    echo "{Key=AutoShutdown,Value=enabled},"
    echo "{Key=CostCenter,Value=Training}"
    echo "]"
}

# Wait for resource to be ready
wait_for_resource() {
    local resource_type=$1
    local resource_id=$2
    local max_wait=${3:-300}  # Default 5 minutes
    
    log_info "Waiting for $resource_type to be ready..."
    
    case $resource_type in
        instance)
            aws ec2 wait instance-running --instance-ids "$resource_id" --max-attempts 40
            ;;
        nat-gateway)
            aws ec2 wait nat-gateway-available --nat-gateway-ids "$resource_id"
            ;;
        *)
            sleep 30  # Generic wait
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log_success "$resource_type is ready"
    else
        log_error "$resource_type failed to become ready"
        return 1
    fi
}

# Show script header
show_header() {
    local script_name=$1
    local team_num=$2
    
    echo "========================================="
    echo "🎓 AppDynamics Lab - $script_name"
    echo "========================================="
    echo ""
    echo "Team: ${team_num}"
    echo "Region: ${AWS_REGION}"
    echo "Profile: ${AWS_PROFILE}"
    echo ""
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error
export -f parse_team_number load_team_config check_aws_cli
export -f resource_exists get_resource_id save_resource_id load_resource_id
export -f mark_step_complete is_step_complete confirm_action
export -f format_tags wait_for_resource show_header
