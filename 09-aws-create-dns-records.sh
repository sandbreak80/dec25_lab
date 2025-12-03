#!/usr/bin/env bash

# Create Route 53 DNS records for AppDynamics Virtual Appliance
# Run this after VMs are created (step 8) when you know the ingress IP

source config.cfg

echo "========================================="
echo "Create DNS Records for AppDynamics VA"
echo "========================================="
echo ""

# Check if INGRESS_IP is set
if [ -z "$INGRESS_IP" ]; then
    echo "❌ INGRESS_IP not set in config.cfg"
    echo ""
    echo "Please add this line to config.cfg:"
    echo "  INGRESS_IP=\"<your-vm-ip>\""
    echo ""
    echo "Or pass as parameter:"
    echo "  INGRESS_IP=10.0.0.10 $0"
    exit 1
fi

echo "Configuration:"
echo "  Domain: ${DNS_DOMAIN}"
echo "  Hosted Zone ID: ${HOSTED_ZONE_ID}"
echo "  Tenant: ${TENANT_NAME}"
echo "  Ingress IP: ${INGRESS_IP}"
echo ""

# Create batch of DNS records
cat > /tmp/dns-changes.json << EOF
{
  "Comment": "AppDynamics VA DNS Records",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${TENANT_NAME}.auth.${DNS_DOMAIN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "${INGRESS_IP}"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${TENANT_NAME}-tnt-authn.${DNS_DOMAIN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "${INGRESS_IP}"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "controller.${DNS_DOMAIN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "${INGRESS_IP}"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "*.${DNS_DOMAIN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "${INGRESS_IP}"}]
      }
    }
  ]
}
EOF

echo "Creating DNS records..."
CHANGE_ID=$(aws --profile ${AWS_PROFILE} route53 change-resource-record-sets \
    --hosted-zone-id ${HOSTED_ZONE_ID} \
    --change-batch file:///tmp/dns-changes.json \
    --query 'ChangeInfo.Id' \
    --output text)

if [ $? -eq 0 ]; then
    echo "✅ DNS records created successfully!"
    echo ""
    echo "Change ID: ${CHANGE_ID}"
    echo ""
    echo "DNS Records Created:"
    echo "  ${TENANT_NAME}.auth.${DNS_DOMAIN} → ${INGRESS_IP}"
    echo "  ${TENANT_NAME}-tnt-authn.${DNS_DOMAIN} → ${INGRESS_IP}"
    echo "  controller.${DNS_DOMAIN} → ${INGRESS_IP}"
    echo "  *.${DNS_DOMAIN} → ${INGRESS_IP}"
    echo ""
    echo "⏳ DNS propagation may take 1-5 minutes"
    echo ""
    echo "Test DNS resolution:"
    echo "  nslookup ${TENANT_NAME}.auth.${DNS_DOMAIN}"
    echo "  nslookup controller.${DNS_DOMAIN}"
    echo ""
    echo "You can now proceed with AppDynamics installation!"
else
    echo "❌ Failed to create DNS records"
    exit 1
fi

# Clean up
rm -f /tmp/dns-changes.json
