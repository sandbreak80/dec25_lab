# Quick Reference: Bootstrap VMs

## VM Connection Info

| VM | Public IP | Private IP | Hostname |
|----|-----------|------------|----------|
| VM 1 (Primary) | 44.232.63.139 | 10.0.0.103 | appdva-vm-1 |
| VM 2 | 54.244.130.46 | 10.0.0.56 | appdva-vm-2 |
| VM 3 | 52.39.239.130 | 10.0.0.177 | appdva-vm-3 |

**Default SSH Password**: `changeme` (change immediately!)  
**New Password**: `FrMoJMZayxBj8@iU`

## Bootstrap Each VM

### VM 1 (Primary) - 44.232.63.139

```bash
ssh appduser@44.232.63.139
# Password: changeme (or FrMoJMZayxBj8@iU if already changed)

sudo appdctl host init
# Enter:
#   Hostname: appdva-vm-1
#   Host IP address (CIDR): 10.0.0.103/24
#   Default gateway: 10.0.0.1
#   DNS server: 8.8.8.8

# Verify
appdctl show boot
# All should show "Succeeded"

exit
```

### VM 2 - 54.244.130.46

```bash
ssh appduser@54.244.130.46
# Password: changeme

sudo appdctl host init
# Enter:
#   Hostname: appdva-vm-2
#   Host IP address (CIDR): 10.0.0.56/24
#   Default gateway: 10.0.0.1
#   DNS server: 8.8.8.8

# Verify
appdctl show boot

exit
```

### VM 3 - 52.39.239.130

```bash
ssh appduser@52.39.239.130
# Password: changeme

sudo appdctl host init
# Enter:
#   Hostname: appdva-vm-3
#   Host IP address (CIDR): 10.0.0.177/24
#   Default gateway: 10.0.0.1
#   DNS server: 8.8.8.8

# Verify
appdctl show boot

exit
```

## Expected Output from `appdctl show boot`

```
NAME              | STATUS    | ERROR 
------------------+-----------+-------
firewall-setup    | Succeeded | --    
hostname          | Succeeded | --    
netplan           | Succeeded | --    
ssh-setup         | Succeeded | --    
storage-setup     | Succeeded | --    
cert-setup        | Succeeded | --    
enable-time-sync  | Succeeded | --    
microk8s-setup    | Succeeded | --    
cloud-init-config | Succeeded | --  
```

⚠️ **If you see errors**: Wait 2-3 minutes and run `appdctl show boot` again. Some services take time to initialize.

## After All VMs Bootstrapped

Proceed to create the cluster:
```bash
./create-cluster.sh
```

Or manually on VM 1:
```bash
ssh appduser@44.232.63.139
appdctl cluster init 10.0.0.56 10.0.0.177
```
