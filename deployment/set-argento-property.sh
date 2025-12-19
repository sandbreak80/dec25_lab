#!/bin/bash
# Set argento.enabled property for SecureApp (Required Post-Install Step)

echo "=== Setting argento.enabled property in Controller database ==="

CONTROLLER_POD=$(kubectl get pods -n cisco-controller --no-headers | grep Running | grep controller-deployment | awk '{print $1}')
echo "Controller pod: $CONTROLLER_POD"

if [ -z "$CONTROLLER_POD" ]; then
    echo "ERROR: Controller pod not found or not running"
    exit 1
fi

echo ""
echo "Setting property..."
kubectl exec -n cisco-controller $CONTROLLER_POD -- bash -c "mysql -h localhost -u controller -pAppDynamics123 controller -e \"INSERT INTO global_configuration_local (name, value) VALUES ('argento.enabled', 'true') ON DUPLICATE KEY UPDATE value='true';\""

echo ""
echo "Verifying property was set..."
kubectl exec -n cisco-controller $CONTROLLER_POD -- bash -c "mysql -h localhost -u controller -pAppDynamics123 controller -e \"SELECT * FROM global_configuration_local WHERE name='argento.enabled';\""

echo ""
echo "✅ Property set! Now testing SecureApp API..."
sleep 5

appdcli run secureapp checkApi

echo ""
echo "=== Done! ==="
echo "If API check passed, you can now upload feeds."


