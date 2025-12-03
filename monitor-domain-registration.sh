#!/usr/bin/env bash

# Monitor domain registration status and update nameservers when ready

source config.cfg

echo "========================================="
echo "Domain Registration Monitor"
echo "========================================="
echo ""
echo "Domain: splunkylabs.com"
echo "Checking registration status..."
echo ""

# Nameservers to use (from hosted zone)
NAMESERVERS=(
    "ns-652.awsdns-17.net"
    "ns-261.awsdns-32.com"
    "ns-1545.awsdns-01.co.uk"
    "ns-1187.awsdns-20.org"
)

while true; do
    # Get operation status
    OPERATION=$(aws --profile ${AWS_PROFILE} route53domains list-operations \
        --region us-east-1 \
        --query 'Operations[?DomainName==`splunkylabs.com`] | [0]' \
        --output json 2>/dev/null)
    
    if [ -z "$OPERATION" ] || [ "$OPERATION" = "null" ]; then
        echo "⏳ Registration in progress... (checking again in 30 seconds)"
        sleep 30
        continue
    fi
    
    STATUS=$(echo "$OPERATION" | jq -r '.Status')
    OPERATION_ID=$(echo "$OPERATION" | jq -r '.OperationId')
    
    echo "Status: $STATUS"
    
    case "$STATUS" in
        "SUCCESSFUL")
            echo ""
            echo "✅ Domain registration completed successfully!"
            echo ""
            echo "Now updating nameservers..."
            
            # Update nameservers
            NS_JSON=$(printf '%s\n' "${NAMESERVERS[@]}" | jq -R . | jq -s '{Name: $name}' --arg name "splunkylabs.com")
            
            aws --profile ${AWS_PROFILE} route53domains update-domain-nameservers \
                --region us-east-1 \
                --domain-name splunkylabs.com \
                --nameservers $(for ns in "${NAMESERVERS[@]}"; do echo "Name=$ns"; done | paste -sd ',' -)
            
            if [ $? -eq 0 ]; then
                echo "✅ Nameservers updated!"
                echo ""
                echo "DNS Configuration Complete:"
                echo "  Domain: splunkylabs.com"
                echo "  Nameservers: ${NAMESERVERS[@]}"
                echo ""
                echo "⏳ DNS propagation will take 5-60 minutes"
                echo ""
                echo "Next steps:"
                echo "  1. Wait 5-10 minutes for DNS to propagate"
                echo "  2. Complete AWS deployment (steps 7-8)"
                echo "  3. Run: INGRESS_IP=<vm-ip> ./09-aws-create-dns-records.sh"
            else
                echo "⚠️ Nameserver update failed. Update manually in AWS Console:"
                echo "   Route 53 → Registered Domains → splunkylabs.com"
                echo "   Set nameservers to:"
                for ns in "${NAMESERVERS[@]}"; do
                    echo "     - $ns"
                done
            fi
            break
            ;;
        "FAILED")
            echo "❌ Domain registration failed!"
            echo "Check AWS Console for details."
            exit 1
            ;;
        *)
            echo "⏳ Still in progress... (Status: $STATUS)"
            echo "   Checking again in 30 seconds..."
            sleep 30
            ;;
    esac
done
