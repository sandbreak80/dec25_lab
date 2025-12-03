#!/bin/bash
# Run this script on VM 1 to update configuration

echo "========================================="
echo "Update AppDynamics Configuration"
echo "========================================="
echo ""

cd /var/appd/config

# Backup original file
sudo cp globals.yaml.gotmpl globals.yaml.gotmpl.backup

# Update DNS domain
echo "Updating dnsDomain to splunkylabs.com..."
sudo sed -i 's|dnsDomain: <domain_name>|dnsDomain: splunkylabs.com|g' globals.yaml.gotmpl

# Update dnsNames - need to be careful with multiline replacement
echo "Updating dnsNames list..."
sudo sed -i '/^dnsNames: &dnsNames$/,/{{ range split/{
    s|  - <domain_name>|  - splunkylabs.com\n  - customer1.auth.splunkylabs.com\n  - customer1-tnt-authn.splunkylabs.com\n  - controller.splunkylabs.com|g
}' globals.yaml.gotmpl

echo "✅ Configuration updated!"
echo ""
echo "Verifying changes:"
grep "dnsDomain:" globals.yaml.gotmpl
echo ""
grep -A 5 "dnsNames:" globals.yaml.gotmpl | head -10
echo ""
echo "========================================="
echo "Configuration Updated Successfully"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Verify DNS resolution: ./dnsinfo.sh"
echo "  2. Create cluster: appdctl cluster init 10.0.0.56 10.0.0.177"
echo "  3. Install services: appdcli start appd small"
echo ""
