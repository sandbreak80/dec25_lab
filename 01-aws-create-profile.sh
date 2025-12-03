#!/bin/bash
# Create AWS Profile for Team
# Usage: ./01-aws-create-profile.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
Usage: $0 --team TEAM_NUMBER

Create AWS CLI profile for a team.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help message

Example:
    $0 --team 1          # Create profile for Team 1

EOF
}

# Parse arguments
TEAM_NUMBER=$(parse_team_number "$@")

# Load team configuration
load_team_config "$TEAM_NUMBER"

# Show header
show_header "Create AWS Profile" "$TEAM_NUMBER"

# Check if profile already exists
if aws configure list --profile "$AWS_PROFILE" &> /dev/null; then
    log_info "Profile '$AWS_PROFILE' already exists"
    
    # Show current configuration
    echo ""
    echo "Current configuration:"
    aws configure list --profile "$AWS_PROFILE"
    echo ""
    
    confirm_action "Do you want to reconfigure this profile?"
fi

# Configure AWS CLI profile
log_info "Configuring AWS CLI profile: $AWS_PROFILE"
echo ""

# Check if we're using IAM user or role
echo "Select authentication method:"
echo "  1) IAM User (Access Key + Secret Key)"
echo "  2) IAM Role (Assume Role)"
read -p "Choice (1 or 2): " auth_method

case $auth_method in
    1)
        # IAM User
        read -p "AWS Access Key ID: " access_key
        read -p "AWS Secret Access Key: " -s secret_key
        echo ""
        
        aws configure set aws_access_key_id "$access_key" --profile "$AWS_PROFILE"
        aws configure set aws_secret_access_key "$secret_key" --profile "$AWS_PROFILE"
        aws configure set region "$AWS_REGION" --profile "$AWS_PROFILE"
        aws configure set output "json" --profile "$AWS_PROFILE"
        ;;
    2)
        # IAM Role
        read -p "Role ARN to assume: " role_arn
        read -p "Source profile (default): " source_profile
        source_profile=${source_profile:-default}
        
        aws configure set role_arn "$role_arn" --profile "$AWS_PROFILE"
        aws configure set source_profile "$source_profile" --profile "$AWS_PROFILE"
        aws configure set region "$AWS_REGION" --profile "$AWS_PROFILE"
        aws configure set output "json" --profile "$AWS_PROFILE"
        ;;
    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

# Verify configuration
log_info "Verifying AWS credentials..."
export AWS_PROFILE="$AWS_PROFILE"

if aws sts get-caller-identity &> /dev/null; then
    log_success "AWS credentials verified!"
    echo ""
    echo "Account Information:"
    aws sts get-caller-identity --output table
    echo ""
else
    log_error "Failed to verify AWS credentials"
    exit 1
fi

# Mark step as complete
mark_step_complete "01-aws-profile" "$TEAM_NUMBER"

log_success "AWS Profile configured for Team ${TEAM_NUMBER}"
echo ""
echo "Profile name: $AWS_PROFILE"
echo "Region: $AWS_REGION"
echo ""
echo "To use this profile:"
echo "  export AWS_PROFILE=$AWS_PROFILE"
echo ""
echo "Next step: ./02-aws-create-vpc.sh --team $TEAM_NUMBER"
