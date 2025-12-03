# Multi-Team Lab Architecture

## 🎓 Lab Overview

**Goal:** 20 students (5 teams of 4) each build a complete AppDynamics Virtual Appliance deployment in AWS.

## 🏗️ Architecture

### Team Isolation

Each team gets a **completely isolated** environment:

```
Team 1                          Team 2                          Team 3
├── VPC: appd-team1-vpc        ├── VPC: appd-team2-vpc        ├── VPC: appd-team3-vpc
├── CIDR: 10.1.0.0/16          ├── CIDR: 10.2.0.0/16          ├── CIDR: 10.3.0.0/16
├── 3 VMs (m5a.4xlarge)        ├── 3 VMs (m5a.4xlarge)        ├── 3 VMs (m5a.4xlarge)
├── ALB + ACM Cert             ├── ALB + ACM Cert             ├── ALB + ACM Cert
└── DNS: team1.splunkylabs.com └── DNS: team2.splunkylabs.com └── DNS: team3.splunkylabs.com

Team 4                          Team 5
├── VPC: appd-team4-vpc        ├── VPC: appd-team5-vpc
├── CIDR: 10.4.0.0/16          ├── CIDR: 10.5.0.0/16
├── 3 VMs (m5a.4xlarge)        ├── 3 VMs (m5a.4xlarge)
├── ALB + ACM Cert             ├── ALB + ACM Cert
└── DNS: team4.splunkylabs.com └── DNS: team5.splunkylabs.com
```

## 🌐 DNS Strategy

### Option 1: Subdomains (RECOMMENDED)
```
Single ACM wildcard certificate: *.splunkylabs.com

Team 1:
  - controller-team1.splunkylabs.com
  - customer1-team1.auth.splunkylabs.com
  - *.team1.splunkylabs.com

Team 2:
  - controller-team2.splunkylabs.com
  - customer1-team2.auth.splunkylabs.com
  - *.team2.splunkylabs.com

... etc for teams 3-5
```

**Advantages:**
- ONE ACM certificate covers all teams
- Simple DNS management
- Easy to scale to more teams
- Clear naming convention

### Option 2: Separate Subdomains with Team-Specific Wildcards
```
ACM certificates:
  - *.team1.splunkylabs.com
  - *.team2.splunkylabs.com
  - *.team3.splunkylabs.com
  - *.team4.splunkylabs.com
  - *.team5.splunkylabs.com

Team 1:
  - controller.team1.splunkylabs.com
  - customer1.auth.team1.splunkylabs.com
```

**Advantages:**
- True isolation per team
- Can revoke/change per team
- More "production-like"

**Disadvantages:**
- 5 separate ACM certificates to manage
- More complex

## 📁 Directory Structure

```
deploy/aws/
├── config/
│   ├── team1.cfg          # Team 1 configuration
│   ├── team2.cfg          # Team 2 configuration
│   ├── team3.cfg          # Team 3 configuration
│   ├── team4.cfg          # Team 4 configuration
│   └── team5.cfg          # Team 5 configuration
│
├── scripts/               # Updated scripts with --team parameter
│   ├── 01-create-profile.sh
│   ├── 02-create-vpc.sh
│   ├── 03-create-s3-bucket.sh
│   ├── 04-import-iam-role.sh
│   ├── 05-upload-ami.sh
│   ├── 06-import-snapshot.sh
│   ├── 07-register-ami.sh
│   ├── 08-create-vms.sh
│   ├── 09-create-alb.sh       # NEW: ALB + ACM setup
│   ├── 10-create-dns.sh       # NEW: Team-specific DNS
│   └── 99-cleanup-team.sh     # NEW: Clean up team env
│
├── lab-guide/
│   ├── 00-INSTRUCTOR-SETUP.md
│   ├── 01-TEAM-ASSIGNMENTS.md
│   ├── 02-AWS-SETUP.md
│   ├── 03-NETWORK-SETUP.md
│   ├── 04-VM-DEPLOYMENT.md
│   ├── 05-ALB-SSL-SETUP.md
│   ├── 06-CLUSTER-SETUP.md
│   ├── 07-APPD-INSTALLATION.md
│   ├── 08-TESTING.md
│   └── 09-CLEANUP.md
│
└── instructor/
    ├── setup-all-teams.sh     # Setup for all 5 teams
    ├── monitor-all-teams.sh   # Monitor all team progress
    ├── cleanup-all-teams.sh   # Clean up all teams
    └── cost-report.sh         # Generate cost report
```

## 💰 Cost Breakdown

### Per Team (Daily)
- **EC2 Instances:** 3 × m5a.4xlarge = 3 × $0.688/hr = $2.064/hr × 24 = **$49.54/day**
- **EBS Storage:** (200GB + 500GB) × 3 = 2,100 GB × $0.10/GB/month = **$7/day**
- **ALB:** $0.0225/hr × 24 = **$0.54/day**
- **Data Transfer:** ~**$2/day** (estimate)
- **Route 53:** Negligible

**Per Team Total: ~$59/day**

### All 5 Teams (8-hour lab day)
- **EC2:** 5 × $2.064/hr × 8 hrs = **$82.56**
- **EBS:** ~**$11.67** (prorated)
- **ALB:** 5 × $0.54/day × 0.33 = **$0.89**
- **Total for 8-hour lab: ~$95**

### Full Week (if left running)
- **5 Teams × $59/day × 7 days = $2,065/week** ⚠️

**CRITICAL:** Scripts must include auto-shutdown!

## 🎯 Student Experience

### Team Assignments
```
Team 1 (Alice, Bob, Charlie, Diana)
  - AWS Account Access
  - Team Config: team1.cfg
  - Domain: team1.splunkylabs.com
  - VPC CIDR: 10.1.0.0/16

Team 2 (Eve, Frank, Grace, Henry)
  - AWS Account Access
  - Team Config: team2.cfg
  - Domain: team2.splunkylabs.com
  - VPC CIDR: 10.2.0.0/16

... etc
```

### Student Workflow
```bash
# 1. Set team number
export TEAM_NUMBER=1

# 2. Run setup script
./lab-setup.sh --team 1

# 3. Follow lab guide (team-specific values auto-populated)
# Script automatically uses:
#   - VPC: appd-team1-vpc (10.1.0.0/16)
#   - S3: appd-team1-bucket
#   - VMs: team1-vm-1, team1-vm-2, team1-vm-3
#   - ALB: appd-team1-alb
#   - DNS: *.team1.splunkylabs.com
```

## 🔒 Security & Isolation

### Network Isolation
- **Separate VPCs** per team (10.1.0.0/16, 10.2.0.0/16, etc.)
- **No VPC peering** between teams
- **Separate Security Groups** per team
- **SSH access** restricted to team's IP range (or instructor IP only)

### IAM Isolation
- Each team gets IAM user/role with permissions scoped to their resources
- Tag-based resource restrictions: `Team=team1`

### Resource Tagging
All resources tagged with:
```json
{
  "Project": "AppDynamics-Lab",
  "Team": "team1",
  "Environment": "lab",
  "Owner": "instructor@company.com",
  "AutoShutdown": "enabled"
}
```

## 🚀 Deployment Strategy

### Phase 1: Instructor Pre-Setup (Day -1)
1. Register/verify domain: `splunkylabs.com`
2. Request single ACM wildcard: `*.splunkylabs.com`
3. Create 5 IAM users (one per team) with scoped permissions
4. Create 5 team config files
5. Upload AMI to shared S3 bucket (one copy, all teams use it)

### Phase 2: Lab Day - Team Deployment (Day 1, 8 hours)
**Hour 1-2: AWS Basics & Setup**
- Students log in to AWS
- Set up AWS CLI with team profile
- Create VPC, subnets, IGW

**Hour 3-4: VM Deployment**
- Import AMI (from shared bucket)
- Create 3 VMs
- Bootstrap VMs

**Hour 5-6: Load Balancer & SSL**
- Create ALB
- Attach ACM certificate
- Configure DNS
- Test HTTPS

**Hour 7-8: AppDynamics Installation**
- Create cluster
- Install AppDynamics services
- Test Controller UI
- Deploy sample app

### Phase 3: Post-Lab Cleanup (Day 1 end)
- Students run cleanup script
- Instructor verifies all resources terminated
- Cost report generated

## 📋 Instructor Tools

### Pre-Lab Setup
```bash
# Setup all 5 teams at once
./instructor/setup-all-teams.sh

# Verify all teams ready
./instructor/verify-all-teams.sh
```

### During Lab Monitoring
```bash
# Monitor all teams' progress
./instructor/monitor-all-teams.sh

# Output:
# Team 1: ✅ VPC Created, ⏳ VMs Deploying
# Team 2: ✅ VPC Created, ✅ VMs Running
# Team 3: ⏳ VPC Creating
# Team 4: ✅ VPC Created, ❌ VM Creation Failed
# Team 5: ✅ VPC Created, ✅ VMs Running
```

### Post-Lab Cleanup
```bash
# Clean up all teams
./instructor/cleanup-all-teams.sh --confirm

# Generate cost report
./instructor/cost-report.sh --date 2025-12-03
```

## 🎓 Learning Objectives

By the end of this lab, students will have:
1. ✅ Built a production-grade AWS VPC from scratch
2. ✅ Deployed a 3-node Kubernetes cluster
3. ✅ Configured Application Load Balancer with SSL
4. ✅ Managed DNS with Route 53
5. ✅ Installed and configured AppDynamics On-Prem
6. ✅ Understood AWS security best practices
7. ✅ Learned infrastructure-as-code concepts
8. ✅ Practiced team collaboration

## 🔄 Reusability

After lab completion:
- All scripts are reusable for production deployments
- Team configs can be adapted for dev/staging/prod
- Students have a complete reference implementation
- Can scale to 10, 20, or more teams by adding configs

## 📝 Next Steps

1. **Create team config files** (team1.cfg - team5.cfg)
2. **Update all scripts** to accept `--team` parameter
3. **Create instructor setup scripts**
4. **Rewrite lab guide** as hands-on build guide
5. **Create monitoring dashboard** for all teams
6. **Set up auto-shutdown** to prevent runaway costs
7. **Create troubleshooting guide** for common student issues

---

**Key Insight:** This architecture teaches students real-world skills while maintaining complete isolation and cost control. Each team gets a production-like experience without interference from other teams.
