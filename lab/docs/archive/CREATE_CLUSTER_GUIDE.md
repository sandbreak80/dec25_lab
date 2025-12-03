# Create AppDynamics VA Cluster - Step by Step

## Prerequisites
✅ All 3 VMs bootstrapped  
✅ All 3 VMs passwords changed to: `FrMoJMZayxBj8@iU`

---

## Step 1: SSH to Primary Node (VM 1)

```bash
ssh appduser@44.232.63.139
# Password: FrMoJMZayxBj8@iU
```

---

## Step 2: Create the Cluster

Run this single command on VM 1:

```bash
appdctl cluster init 10.0.0.56 10.0.0.177
```

**What happens:**
- The command will prompt you for the password of VM 2 and VM 3
- Enter `FrMoJMZayxBj8@iU` when prompted
- It will set up SSH keys between nodes automatically
- It will create the Kubernetes cluster
- Takes 1-2 minutes

**Expected prompts:**
```
Copying ID to appduser@10.0.0.56
Password: FrMoJMZayxBj8@iU

Copying ID to appduser@10.0.0.177  
Password: FrMoJMZayxBj8@iU

Creating cluster...
[Progress messages]
Cluster created successfully
```

---

## Step 3: Verify Cluster Status

Still on VM 1, run:

```bash
appdctl show cluster
```

**Expected output:**
```
 NODE              | ROLE  | RUNNING 
-------------------+-------+---------
 10.0.0.103:19001  | voter | true    
 10.0.0.56:19001   | voter | true    
 10.0.0.177:19001  | voter | true
```

✅ All nodes should show `RUNNING: true`

Also verify Kubernetes:
```bash
microk8s status
```

Should show: `microk8s is running` with high-availability enabled

---

## Step 4: Check Cluster Health

```bash
# Check nodes
microk8s kubectl get nodes

# Should show all 3 nodes as Ready
```

---

## Troubleshooting

### If cluster init fails:

**Error**: "Host key verification failed"
```bash
# On VM 1, clear known_hosts and retry
rm ~/.ssh/known_hosts
appdctl cluster init 10.0.0.56 10.0.0.177
```

**Error**: "Connection refused"
- Check that all 3 VMs can ping each other
- Verify security group allows traffic between VMs (10.0.0.0/24)

**Error**: "Node not ready"
- Wait 1-2 minutes and check again
- Run: `appdctl show boot` on each node
- All services must show "Succeeded"

---

## After Cluster is Created

You'll see confirmation message and all nodes showing as voters.

**Next steps:**
1. Configure AppDynamics settings
2. Copy license file
3. Install AppDynamics services

---

## Quick Copy-Paste Commands

```bash
# SSH to VM 1
ssh appduser@44.232.63.139

# Create cluster (enter password when prompted: FrMoJMZayxBj8@iU)
appdctl cluster init 10.0.0.56 10.0.0.177

# Verify cluster
appdctl show cluster
microk8s status

# Exit
exit
```

---

**This should take about 2-3 minutes total!**
