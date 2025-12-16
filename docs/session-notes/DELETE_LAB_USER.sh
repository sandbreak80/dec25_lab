#!/bin/bash
# Delete lab-student IAM user and policy after lab week
# Run this after December 23, 2025

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Delete Lab Student IAM User                            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
USER_NAME="lab-student"
POLICY_NAME="AppDynamicsLabStudentPolicy"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "This will delete:"
echo "  - IAM User: $USER_NAME"
echo "  - Access keys for $USER_NAME"
echo "  - IAM Policy: $POLICY_NAME"
echo ""
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Step 1: Deleting access keys..."
ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[*].AccessKeyId' --output text)
for KEY in $ACCESS_KEYS; do
    echo "  Deleting access key: $KEY"
    aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$KEY"
done
echo "✅ Access keys deleted"

echo ""
echo "Step 2: Detaching policy from user..."
aws iam detach-user-policy --user-name "$USER_NAME" --policy-arn "$POLICY_ARN"
echo "✅ Policy detached"

echo ""
echo "Step 3: Deleting IAM user..."
aws iam delete-user --user-name "$USER_NAME"
echo "✅ User deleted"

echo ""
echo "Step 4: Deleting IAM policy..."
aws iam delete-policy --policy-arn "$POLICY_ARN"
echo "✅ Policy deleted"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Lab student access completely removed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Verify all student resources are cleaned up:"
echo "     aws ec2 describe-instances --filters Name=tag:ManagedBy,Values=AppDynamicsLab"
echo "  2. Delete credential files:"
echo "     rm -f STUDENT_CREDENTIALS.txt lab-student-credentials.json"
echo ""
