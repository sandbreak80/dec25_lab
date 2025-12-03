#!/usr/bin/env bash

# Register domain in AWS Route 53 with correct contact information format

source config.cfg

DOMAIN_NAME="appd-labs.com"

echo "========================================="
echo "Register Domain: ${DOMAIN_NAME}"
echo "========================================="
echo ""

# Check availability first
echo "Checking domain availability..."
AVAILABLE=$(aws --profile ${AWS_PROFILE} route53domains check-domain-availability \
    --domain-name ${DOMAIN_NAME} \
    --region us-east-1 \
    --query 'Availability' \
    --output text)

echo "Status: ${AVAILABLE}"

if [ "$AVAILABLE" != "AVAILABLE" ]; then
    echo "❌ Domain is not available. Try another name."
    exit 1
fi

echo ""
echo "Please enter contact information:"
echo "(Phone format: +1.5551234567 - must include country code +1)"
echo ""

read -p "First Name: " FIRST_NAME
read -p "Last Name: " LAST_NAME
read -p "Email: " EMAIL
read -p "Phone (format +1.5551234567): " PHONE
read -p "Address Line 1: " ADDRESS
read -p "City: " CITY
read -p "State (2 letters, e.g., CA): " STATE
read -p "Zip Code: " ZIP

echo ""
echo "Registering domain ${DOMAIN_NAME}..."
echo "This will charge approximately $12-15 to your AWS account."
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Registration cancelled."
    exit 0
fi

# Create contact JSON
cat > /tmp/domain-contact.json << EOF
{
    "FirstName": "${FIRST_NAME}",
    "LastName": "${LAST_NAME}",
    "ContactType": "PERSON",
    "AddressLine1": "${ADDRESS}",
    "City": "${CITY}",
    "State": "${STATE}",
    "CountryCode": "US",
    "ZipCode": "${ZIP}",
    "PhoneNumber": "${PHONE}",
    "Email": "${EMAIL}"
}
EOF

# Register domain
aws --profile ${AWS_PROFILE} route53domains register-domain \
    --region us-east-1 \
    --domain-name ${DOMAIN_NAME} \
    --duration-in-years 1 \
    --auto-renew \
    --admin-contact file:///tmp/domain-contact.json \
    --registrant-contact file:///tmp/domain-contact.json \
    --tech-contact file:///tmp/domain-contact.json \
    --privacy-protection

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Domain registration submitted!"
    echo ""
    echo "Registration usually takes 5-15 minutes to complete."
    echo "You'll receive email confirmation when ready."
    echo ""
    echo "After registration completes:"
    echo "  1. Update nameservers to use the hosted zone"
    echo "  2. Or run ./09-aws-create-dns-records.sh"
else
    echo ""
    echo "❌ Registration failed. Check the error above."
fi

rm -f /tmp/domain-contact.json
