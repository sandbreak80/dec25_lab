#!/bin/bash
# Create IAM users and policies for AppDynamics lab students
# Usage: ./scripts/create-student-iam.sh --students 5 --group AppDLabStudents

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Create IAM Access for Lab Students                    ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 [OPTIONS]

Options:
    --students N          Number of students (default: 5)
    --group NAME          IAM group name (default: AppDLabStudents)
    --policy-name NAME    Policy name (default: AppDynamicsLabStudentPolicy)
    --prefix PREFIX       Username prefix (default: appd-student)
    --create-users        Create IAM users
    --create-policy       Create IAM policy
    --create-group        Create IAM group
    --attach-policy       Attach policy to group
    --all                 Do everything (create policy, group, users)
    --output FILE         Save credentials to file (default: student-credentials.txt)
    --help                Show this help

Examples:
    # Create everything for 5 students
    $0 --all --students 5

    # Just create the policy
    $0 --create-policy

    # Create users and add to existing group
    $0 --create-users --students 5 --group MyExistingGroup

EOF
    exit 0
}

# Defaults
NUM_STUDENTS=5
GROUP_NAME="AppDLabStudents"
POLICY_NAME="AppDynamicsLabStudentPolicy"
USERNAME_PREFIX="appd-student"
CREATE_USERS=false
CREATE_POLICY=false
CREATE_GROUP=false
ATTACH_POLICY=false
OUTPUT_FILE="student-credentials.txt"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --students) NUM_STUDENTS="$2"; shift 2 ;;
        --group) GROUP_NAME="$2"; shift 2 ;;
        --policy-name) POLICY_NAME="$2"; shift 2 ;;
        --prefix) USERNAME_PREFIX="$2"; shift 2 ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        --create-users) CREATE_USERS=true; shift ;;
        --create-policy) CREATE_POLICY=true; shift ;;
        --create-group) CREATE_GROUP=true; shift ;;
        --attach-policy) ATTACH_POLICY=true; shift ;;
        --all) CREATE_POLICY=true; CREATE_GROUP=true; ATTACH_POLICY=true; CREATE_USERS=true; shift ;;
        --help|-h) show_usage ;;
        *) echo -e "${RED}Unknown parameter: $1${NC}"; show_usage ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  AppDynamics Lab - Student IAM Setup                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${BLUE}ℹ️  AWS Account: $ACCOUNT_ID${NC}"
echo -e "${BLUE}ℹ️  Region: $(aws configure get region || echo 'us-west-2')${NC}"
echo ""

# Create IAM policy
if [ "$CREATE_POLICY" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Creating IAM Policy: $POLICY_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if aws iam get-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Policy already exists, skipping...${NC}"
    else
        aws iam create-policy \
            --policy-name "$POLICY_NAME" \
            --policy-document file://"${SCRIPT_DIR}/iam-student-policy.json" \
            --description "Restricted permissions for AppDynamics lab students"
        echo -e "${GREEN}✅ Policy created: arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}${NC}"
    fi
    echo ""
fi

# Create IAM group
if [ "$CREATE_GROUP" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Creating IAM Group: $GROUP_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if aws iam get-group --group-name "$GROUP_NAME" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Group already exists, skipping...${NC}"
    else
        aws iam create-group --group-name "$GROUP_NAME"
        echo -e "${GREEN}✅ Group created: $GROUP_NAME${NC}"
    fi
    echo ""
fi

# Attach policy to group
if [ "$ATTACH_POLICY" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Attaching Policy to Group"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    aws iam attach-group-policy \
        --group-name "$GROUP_NAME" \
        --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
    echo -e "${GREEN}✅ Policy attached to group${NC}"
    echo ""
fi

# Create users
if [ "$CREATE_USERS" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Creating $NUM_STUDENTS Student Users"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Clear output file
    cat > "$OUTPUT_FILE" << EOF
AppDynamics Lab - Student Credentials
Generated: $(date)
Account ID: $ACCOUNT_ID
Region: us-west-2

IMPORTANT: Give each student ONLY their own credentials!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
    
    for i in $(seq 1 $NUM_STUDENTS); do
        USERNAME="${USERNAME_PREFIX}${i}"
        
        echo -e "${BLUE}Creating user: $USERNAME${NC}"
        
        # Create user
        if aws iam get-user --user-name "$USERNAME" &>/dev/null; then
            echo -e "${YELLOW}⚠️  User already exists, skipping creation...${NC}"
        else
            aws iam create-user --user-name "$USERNAME" --tags Key=Purpose,Value=AppDynamicsLab
            echo -e "${GREEN}✅ User created${NC}"
        fi
        
        # Add to group
        aws iam add-user-to-group --user-name "$USERNAME" --group-name "$GROUP_NAME"
        echo -e "${GREEN}✅ Added to group: $GROUP_NAME${NC}"
        
        # Create access key
        KEY_OUTPUT=$(aws iam create-access-key --user-name "$USERNAME" --output json)
        ACCESS_KEY=$(echo "$KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
        SECRET_KEY=$(echo "$KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')
        
        echo -e "${GREEN}✅ Access key created${NC}"
        echo ""
        
        # Save to file
        cat >> "$OUTPUT_FILE" << EOF
Student $i - Username: $USERNAME
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AWS_ACCESS_KEY_ID=$ACCESS_KEY
AWS_SECRET_ACCESS_KEY=$SECRET_KEY
AWS_REGION=us-west-2

To configure AWS CLI:
  aws configure
  # Enter the above Access Key ID and Secret Access Key

To verify access:
  aws sts get-caller-identity
  ./scripts/check-prerequisites.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
    done
    
    echo -e "${GREEN}✅ All users created and added to group${NC}"
    echo -e "${GREEN}✅ Credentials saved to: $OUTPUT_FILE${NC}"
    echo ""
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$CREATE_POLICY" = true ]; then
    echo -e "${GREEN}✅ Policy: arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}${NC}"
fi

if [ "$CREATE_GROUP" = true ]; then
    echo -e "${GREEN}✅ Group: $GROUP_NAME${NC}"
fi

if [ "$CREATE_USERS" = true ]; then
    echo -e "${GREEN}✅ Users: ${USERNAME_PREFIX}1 through ${USERNAME_PREFIX}${NUM_STUDENTS}${NC}"
    echo -e "${GREEN}✅ Credentials file: $OUTPUT_FILE${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next Steps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Distribute credentials to students"
echo "   - Give each student ONLY their section from $OUTPUT_FILE"
echo "   - Do NOT send credentials via email (use secure method)"
echo ""
echo "2. Students should:"
echo "   - Run: aws configure"
echo "   - Enter their Access Key ID and Secret Access Key"
echo "   - Run: ./scripts/check-prerequisites.sh"
echo "   - Start deployment: ./lab-deploy.sh --team N"
echo ""
echo "3. After lab ends:"
echo "   - Deactivate access keys: ./scripts/deactivate-student-access.sh"
echo "   - Or delete users: ./scripts/delete-student-iam.sh"
echo ""
echo "4. Monitor student usage:"
echo "   aws ec2 describe-instances --filters Name=tag:ManagedBy,Values=AppDynamicsLab"
echo ""
