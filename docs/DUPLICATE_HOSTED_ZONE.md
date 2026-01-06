# Duplicate Hosted Zone Issue - RESOLVED

## Problem Summary

**Issue**: Two Route53 hosted zones existed for `splunkylabs.com`, costing extra money and causing potential confusion.

## Analysis

### Active Zone (Z06491142QTF1FNN8O9PR) ✅
- **Records**: 4 (SOA, NS, ACM validation CNAME, ACME challenge TXT)
- **Status**: Domain nameservers point to this zone
- **Usage**: All config files reference this zone
- **Action**: **KEPT** - This is the correct zone

### Orphaned Zone (Z0008805DDX7D9TKACJ5) ❌
- **Records**: 2 (only SOA and NS - defaults)
- **Status**: Not used by the domain (different nameservers)
- **Usage**: No config files reference this zone
- **Action**: **DELETED** - Wasting $0.50/month

## Cost Impact

- **Monthly waste**: $0.50 per unused zone
- **Annual waste**: $6.00/year
- **Status**: ✅ Resolved - duplicate zone deleted

## Root Cause

The duplicate zone was likely created due to one of:

1. **Accidental creation** - Zone created twice during initial lab setup
2. **Testing** - Someone tested zone creation and forgot to clean up
3. **Migration** - Old zone from previous setup not properly cleaned
4. **Script error** - Deployment script ran twice

## How Duplicates Were Detected

### 1. Listed all hosted zones:
```bash
aws route53 list-hosted-zones
```

### 2. Checked which zone the domain uses:
```bash
dig +short NS splunkylabs.com
```

### 3. Compared nameservers:
```bash
aws route53 get-hosted-zone --id Z06491142QTF1FNN8O9PR
aws route53 get-hosted-zone --id Z0008805DDX7D9TKACJ5
```

### 4. Verified config file references:
```bash
grep -r "HOSTED_ZONE_ID" config/
```

**Result**: Only Zone 1 (Z06491142QTF1FNN8O9PR) is referenced and active.

## Resolution

### Script Created
`scripts/cleanup-duplicate-hosted-zone.sh`

**Features**:
- Verifies which zone is active
- Compares domain nameservers with zone nameservers
- Shows records in both zones
- Safely deletes only the orphaned zone
- Confirms before deletion
- Provides detailed analysis

### Deletion Process

1. **Verified active zone** - Confirmed domain points to Z06491142QTF1FNN8O9PR
2. **Checked orphaned zone** - Confirmed Z0008805DDX7D9TKACJ5 has no custom records
3. **Deleted orphaned zone** - Removed Z0008805DDX7D9TKACJ5
4. **Verified result** - Only one zone remains

### Execution Log

```
Date: December 19, 2025
Action: Deleted orphaned hosted zone Z0008805DDX7D9TKACJ5
Result: Success
Savings: $0.50/month ($6/year)
```

## Current State

**Hosted Zones**: 1 (was 2)
- ✅ `Z06491142QTF1FNN8O9PR` - splunkylabs.com (4 records) - ACTIVE

**DNS Records in Active Zone**:
1. **SOA** - Start of Authority (required)
2. **NS** - Name servers (required)
3. **CNAME** - `_5f2c88235edb74fa216b3bbbdcb35ae5.splunkylabs.com` (ACM validation)
4. **TXT** - `_acme-challenge.splunkylabs.com` (ACME challenge)

## Prevention

To prevent duplicate zones in future:

### 1. Check Before Creating
```bash
# Always check if zone exists first
aws route53 list-hosted-zones-by-name --dns-name splunkylabs.com
```

### 2. Use Idempotent Scripts
```bash
# Script pattern for zone creation
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name "$DOMAIN" \
    --query "HostedZones[?Name=='${DOMAIN}.'].Id" \
    --output text | cut -d'/' -f3)

if [ -z "$ZONE_ID" ]; then
    echo "Creating hosted zone..."
    aws route53 create-hosted-zone --name "$DOMAIN" --caller-reference "$(date +%s)"
else
    echo "Hosted zone already exists: $ZONE_ID"
fi
```

### 3. Add to Cleanup Scripts
```bash
# Check for duplicate zones during cleanup
ZONE_COUNT=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='splunkylabs.com.'].Id" \
    --output text | wc -l)

if [ "$ZONE_COUNT" -gt 1 ]; then
    echo "WARNING: Multiple hosted zones found for splunkylabs.com"
fi
```

### 4. Regular Audits
```bash
# Monthly check for duplicate zones
aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id]' --output text | \
    awk '{print $1}' | sort | uniq -d
```

## Verification Commands

### Check current hosted zones:
```bash
aws route53 list-hosted-zones
```

### Verify domain nameservers match zone:
```bash
# Get domain nameservers
dig +short NS splunkylabs.com

# Get zone nameservers
aws route53 get-hosted-zone --id Z06491142QTF1FNN8O9PR \
    --query 'DelegationSet.NameServers' --output table
```

### Check for duplicates:
```bash
# List all zones and count duplicates
aws route53 list-hosted-zones --query 'HostedZones[*].Name' --output text | \
    tr '\t' '\n' | sort | uniq -c | awk '$1 > 1'
```

## Cost Summary

### Before Cleanup
- **Zones**: 2
- **Monthly cost**: $1.00 ($0.50 × 2)
- **Annual cost**: $12.00

### After Cleanup
- **Zones**: 1
- **Monthly cost**: $0.50
- **Annual cost**: $6.00
- **Savings**: $6.00/year (50% reduction)

## Related Files

**Scripts**:
- `scripts/cleanup-duplicate-hosted-zone.sh` - Duplicate zone cleanup (NEW)
- `scripts/cleanup-orphaned-dns.sh` - DNS record cleanup

**Documentation**:
- `docs/DUPLICATE_HOSTED_ZONE.md` - This file
- `docs/DNS_CLEANUP_SUMMARY.md` - DNS record cleanup
- `docs/COMPLETE_CLEANUP_SUMMARY.md` - Overall cleanup summary

**Configuration**:
All config files correctly reference the active zone:
- `config/team*.cfg` - HOSTED_ZONE_ID="Z06491142QTF1FNN8O9PR"
- `lab/config/team*.cfg` - HOSTED_ZONE_ID="Z06491142QTF1FNN8O9PR"

## Status

✅ **RESOLVED** - December 19, 2025
- Duplicate zone deleted
- Cost savings: $0.50/month
- Only one hosted zone remains
- All DNS records preserved in active zone
