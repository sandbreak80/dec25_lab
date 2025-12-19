#!/bin/bash
# Enable SecureApp by setting argento.enabled property

echo "=== Enabling SecureApp (Setting argento.enabled property) ==="

# Get Controller pod name
CONTROLLER_POD=$(kubectl get pods -n cisco-controller -l app=controller -o name | head -1 | cut -d'/' -f2)
echo "Controller pod: $CONTROLLER_POD"

# Set the property in the database
echo "Setting argento.enabled=true in database..."
kubectl exec -n cisco-controller "$CONTROLLER_POD" -- bash -c "mysql -h localhost -u controller -pAppDynamics123 controller -e \"INSERT INTO global_configuration_local (name, value) VALUES ('argento.enabled', 'true') ON DUPLICATE KEY UPDATE value='true';\""

echo ""
echo "Verifying property was set..."
kubectl exec -n cisco-controller "$CONTROLLER_POD" -- bash -c "mysql -h localhost -u controller -pAppDynamics123 controller -e \"SELECT * FROM global_configuration_local WHERE name='argento.enabled';\""

echo ""
echo "=== Restarting Controller to apply changes ==="
kubectl rollout restart deployment/controller-deployment -n cisco-controller

echo ""
echo "Wait 5 minutes for Controller to restart, then check SecureApp status with:"
echo "  appdcli ping | grep SecureApp"
echo "  appdcli run secureapp health"


