# Enable SecureApp Property (Post-Installation Required Step)

## Official Documentation Requirement

Per Cisco AppDynamics documentation, **after installing SecureApp**, you MUST enable it via the Administration Console:

### Steps to Enable SecureApp:

1. **Login to Administration Console**:
   ```
   https://team5.splunkylabs.com/controller/admin.jsp
   ```
   - Username: `admin`
   - Password: `welcome`

2. **Navigate to Account Settings**:
   - Click on the account name (usually `customer1`)
   - Click **"Edit"** button

3. **Add Property**:
   - Scroll to **"Properties"** section
   - Add new property:
     - **Name**: `argento.enabled`
     - **Value**: `true`
   - Click **"Save"**

4. **Log Out and Log Back In**:
   - Log out of Admin Console
   - Log back into regular Controller UI

5. **Verify**:
   ```bash
   ssh appduser@54.200.217.241
   appdcli run secureapp health
   ```
   
   Should now show:
   ```
   Account properties are configured for Secure App
   ```

## Alternative: Set via Database (If UI Not Accessible)

```bash
CONTROLLER_POD=$(kubectl get pods -n cisco-controller -l app=controller -o name | head -1 | cut -d'/' -f2)

kubectl exec -n cisco-controller $CONTROLLER_POD -- bash -c \
  "mysql -h localhost -u controller -pAppDynamics123 controller \
   -e \"INSERT INTO global_configuration_local (name, value) VALUES ('argento.enabled', 'true') ON DUPLICATE KEY UPDATE value='true';\""
```

## Why This Is Required

- SecureApp API calls check for this property
- Without it, all API endpoints return HTTP 500
- This includes:
  - `uploadFeed`
  - `setFeedKey`
  - `secureApplications`
  - `checkApi`

## After Setting the Property

Once the property is set, you can proceed with feed configuration:

```bash
# For manual feed upload (air-gapped):
appdcli run secureapp setFeedKey /var/appd/config/feed_key.yaml
appdcli run secureapp uploadFeed /home/appduser/secapp_data_25.12.18.1765984004.dat

# OR for automatic download:
appdcli run secureapp setDownloadPortalCredentials <username>
```

## References

- Cisco AppDynamics Virtual Appliance Documentation
- Post-Installation Steps for Secure Application
- Section: "Enable the Cisco Secure Application Service in the Controller Account"


