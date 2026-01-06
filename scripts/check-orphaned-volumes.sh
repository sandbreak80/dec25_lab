#!/bin/bash
# Quick check for orphaned volumes

echo "Checking for orphaned 500GB volumes..."
echo ""

VOLUME_COUNT=$(aws ec2 describe-volumes \
    --filters "Name=size,Values=500" "Name=status,Values=available" \
    --query 'Volumes[*].VolumeId' \
    --output text | wc -w | tr -d ' ')

if [ "$VOLUME_COUNT" -eq 0 ]; then
    echo "✅ No orphaned 500GB volumes found!"
else
    TOTAL_GB=$((VOLUME_COUNT * 500))
    TOTAL_TB=$(echo "scale=2; $TOTAL_GB / 1024" | bc)
    MONTHLY_COST=$((TOTAL_GB * 10 / 100))
    
    echo "⚠️  Found: ${VOLUME_COUNT} orphaned 500GB volumes"
    echo "    Total: ${TOTAL_TB} TB (${TOTAL_GB} GB)"
    echo "    Cost:  ~\$${MONTHLY_COST}/month"
    echo ""
    echo "To clean up, run:"
    echo "    ./scripts/cleanup-all-orphaned-volumes.sh"
fi
