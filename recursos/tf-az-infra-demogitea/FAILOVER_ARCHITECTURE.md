# Azure Failover Architecture - Summary

## 🎯 Your Failover Strategy Explained

### Normal Operations (AWS Primary)

```
┌─────────────────────────────┐     ┌─────────────────────────────┐
│       AWS (PRODUCTION)      │     │   Azure (DB ONLY - Standby) │
├─────────────────────────────┤     ├─────────────────────────────┤
│                             │     │                             │
│  👥 Users → ALB → EC2       │     │  ❌ NO VM                   │
│                  ↓          │     │  ❌ NO Load Balancer        │
│           RDS MySQL ────────┼─────┼──→ ✅ MySQL Replica        │
│           (Master)          │ VPN │     (Replicating)           │
│                             │     │                             │
│  💰 Cost: ~$100/month       │     │  💰 Cost: ~$25/month        │
└─────────────────────────────┘     └─────────────────────────────┘
                                                 ▲
                                                 │
                                          Continuous MySQL
                                           Replication
                                           (< 1 sec lag)
```

**Why this approach?**

- ✅ **Cost Savings**: Only pay for database in Azure (~$25/month vs ~$100/month full stack)
- ✅ **Data Ready**: Database always has latest data from AWS
- ✅ **Fast Failover**: Deploy app infra in ~15-20 minutes when needed
- ✅ **No waste**: Don't pay for idle VMs and load balancers

---

### When AWS Fails (Failover Activation)

```
┌─────────────────────────────┐     ┌─────────────────────────────┐
│       AWS ❌ DOWN           │     │   Azure (ACTIVATING)        │
├─────────────────────────────┤     ├─────────────────────────────┤
│                             │     │                             │
│  ❌ Users can't access      │     │  1️⃣ Run Jenkins Pipeline    │
│  ❌ EC2 unreachable         │     │     - FAILOVER mode         │
│  ❌ RDS unreachable         │     │                             │
│                             │     │  2️⃣ Terraform creates:      │
│                             │     │     - VM (Standard_B2s)     │
│                             │     │     - Load Balancer         │
│                             │     │     - Public IP             │
│                             │     │                             │
│                             │     │  3️⃣ Ansible installs:       │
│                             │     │     - Gitea binary          │
│                             │     │     - Connects to MySQL     │
│                             │     │     - Starts service        │
│                             │     │                             │
│                             │     │  4️⃣ Promote MySQL:          │
│                             │     │     STOP SLAVE;             │
│                             │     │     RESET SLAVE ALL;        │
│                             │     │                             │
│                             │     │  ⏱️ Total Time: ~20 min     │
└─────────────────────────────┘     └─────────────────────────────┘
```

---

### After Failover (Azure Primary)

```
┌─────────────────────────────┐     ┌─────────────────────────────┐
│       AWS ❌ DOWN           │     │   Azure ✅ ACTIVE           │
├─────────────────────────────┤     ├─────────────────────────────┤
│                             │     │                             │
│  (Infrastructure offline)   │     │  👥 Users → LB → VM         │
│                             │     │                  ↓          │
│                             │     │           MySQL (Master)    │
│                             │     │           ✅ Latest Data     │
│                             │     │                             │
│                             │     │  💰 Cost: ~$100/month       │
│                             │     │     (now full stack)        │
└─────────────────────────────┘     └─────────────────────────────┘

✅ Gitea accessible at: http://<AZURE_LB_IP>
✅ All repositories intact
✅ All user data preserved
✅ Data loss: < 1 second (replication lag)
```

---

## 🚀 How to Execute Failover

### Step 1: Detect AWS Failure

```bash
# Monitoring should alert you
# Or manual check:
curl http://aws-gitea-url.com  # Fails
```

### Step 2: Run Jenkins Pipeline

```
Jenkins → Azure-Gitea-Deployment → Build with Parameters

Parameters:
┌──────────────────────────────────────────────────┐
│ PLAN_TERRAFORM:     ✅ true                      │
│ APPLY_TERRAFORM:    ✅ true                      │
│ DEPLOY_ANSIBLE:     ✅ true                      │
│ DESTROY_TERRAFORM:  ❌ false                     │
│ DEPLOYMENT_MODE:    🎯 FAILOVER                  │
└──────────────────────────────────────────────────┘

Click: [Build]
```

**What Jenkins does:**

1. ✅ Clones Terraform and Ansible repos
2. ✅ Runs `terraform apply` → Creates VM + Load Balancer
3. ✅ Extracts outputs (VM IP, MySQL host)
4. ✅ Generates Ansible inventory automatically
5. ✅ Runs Ansible → Installs Gitea
6. ✅ Verifies Gitea is accessible
7. ✅ Sends Discord notification with URL

⏱️ **Time: ~15-20 minutes**

### Step 3: Promote Azure MySQL

```bash
# SSH to Azure VM
ssh azureuser@<AZURE_VM_IP>

# Connect to MySQL
mysql -h <AZURE_MYSQL_HOST> -u gitea_admin -p

# Promote replica to standalone
mysql> STOP SLAVE;
mysql> RESET SLAVE ALL;
mysql> SHOW MASTER STATUS;  # Verify it's now master

# Exit
mysql> EXIT;
```

⏱️ **Time: ~2 minutes**

### Step 4: Verify Gitea

```bash
# Test Gitea is accessible
curl http://<AZURE_LB_IP>:3000

# Or open in browser:
http://<AZURE_LB_IP>:3000
```

### Step 5: Update DNS (if using custom domain)

```bash
# Update your DNS records to point to Azure
# Example with AWS Route53:
aws route53 change-resource-record-sets \
    --hosted-zone-id Z1234567890ABC \
    --change-batch file://change-dns-to-azure.json

# Or manually in your DNS provider:
gitea.yourdomain.com → <AZURE_LB_IP>
```

⏱️ **DNS propagation: 5-60 minutes**

---

## 📋 Jenkins Pipeline Modes

### Mode 1: FAILOVER (AWS Failed - Deploy App Only)

**When to use**: AWS is down, database already exists and has data

```yaml
DEPLOYMENT_MODE: FAILOVER
```

**What it deploys:**

- ✅ Virtual Machine
- ✅ Load Balancer
- ✅ Network Interface
- ✅ Public IP
- ✅ Gitea Application (via Ansible)
- ❌ Database (assumes it exists)

**Cost**: ~$75/month additional (total ~$100/month)

**Use case**: Emergency failover

---

### Mode 2: FULL_STACK (Initial Setup)

**When to use**: First time deployment, setting up replication

```yaml
DEPLOYMENT_MODE: FULL_STACK
```

**What it deploys:**

- ✅ Resource Group
- ✅ Virtual Network + Subnets
- ✅ MySQL Flexible Server
- ✅ VPN Gateway (if enabled)
- ✅ Virtual Machine (if Ansible enabled)
- ✅ Load Balancer (if Ansible enabled)
- ✅ Gitea Application (if Ansible enabled)

**Cost**: ~$100/month (or ~$250/month with VPN)

**Use case**: Initial infrastructure setup, testing

---

## 💾 What About the Data?

### How Data Stays Current

```
AWS RDS (Master)
   │
   │ Every SQL operation:
   │ - INSERT user
   │ - CREATE repository
   │ - PUSH commit
   │ - UPDATE pull request
   │
   ├── Writes to binlog
   │
   ▼
Through VPN Tunnel (secure)
   │
   ▼
Azure MySQL (Replica)
   │
   ├── Reads binlog
   ├── Applies same operations
   └── Keeps data synchronized
```

**Replication Lag**: < 1 second under normal conditions

**What gets replicated:**

- ✅ All Git repositories
- ✅ All user accounts
- ✅ All pull requests
- ✅ All issues
- ✅ All commits
- ✅ All settings

**Data loss during failover**: Typically < 1 second of data (operations that happened after last replication)

---

## 🔄 Recovery Options After AWS Comes Back

### Option A: Keep Azure as Primary

**Steps:**

1. ✅ Azure is already running
2. ✅ Users are already using it
3. ❌ Leave AWS infrastructure stopped
4. 💰 Save AWS costs (~$100/month)

**When to choose**: If AWS region has reliability issues

---

### Option B: Return to AWS as Primary

**Steps:**

1. 🔄 Reverse replication direction (Azure → AWS)
2. ⏳ Wait for AWS RDS to catch up
3. 🔁 Switch DNS back to AWS
4. ❌ Stop Azure VM + LB
5. ✅ Azure goes back to DB-only mode

**When to choose**: If AWS is your preferred region

---

### Option C: Keep Both Active (Advanced)

**Steps:**

1. ✅ Keep both AWS and Azure running
2. 🔄 Use DNS-based load balancing
3. 🌍 Geo-distribute traffic

**Cost**: ~$200/month (both clouds)

**When to choose**: High availability requirements

---

## 💰 Cost Comparison

| Scenario               | AWS Cost | Azure Cost | Total    | Purpose                 |
| ---------------------- | -------- | ---------- | -------- | ----------------------- |
| **Normal Ops**         | ~$100    | ~$25       | **$125** | Production + standby DB |
| **During Failover**    | $0       | ~$100      | **$100** | Azure becomes primary   |
| **After AWS Recovery** | ~$100    | ~$25       | **$125** | Back to normal          |
| **Both Active**        | ~$100    | ~$100      | **$200** | High availability       |

---

## ⚠️ Important Notes

### 1. Database Must Exist First

Before running Jenkins in FAILOVER mode:

- ✅ Azure MySQL must already be deployed
- ✅ Replication must be active
- ✅ VPN tunnel must be established

**If database doesn't exist**, use FULL_STACK mode first.

### 2. Jenkinsfile Location

**Q: Can the Jenkinsfile be at the root of tf-az-infra-demoGitea?**

**A: YES!** ✅ It's already there:

```
TF-AZ-INFRA-DEMOGITEA/
├── Jenkinsfile              ← HERE
├── JENKINS_SETUP.md
├── README.md
├── infra/
└── modules/
```

Jenkins will:

1. Clone this repo
2. Find `Jenkinsfile` in the root
3. Execute the pipeline
4. Clone ansible-az-demoGitea as needed

### 3. Testing the Pipeline

**Recommendation**: Test in a separate Azure subscription or resource group first:

```hcl
# terraform.tfvars
project_name = "gitea-test"  # Different name
environment  = "test"        # Different environment
```

This way you can validate the Jenkins pipeline works before relying on it for failover.

---

## 📚 Related Documentation

- [README.md](./README.md) - Complete Azure infrastructure guide
- [JENKINS_SETUP.md](./JENKINS_SETUP.md) - Detailed Jenkins configuration
- [REPOSITORY_RELATIONSHIPS.md](./REPOSITORY_RELATIONSHIPS.md) - Multi-cloud architecture
- [TF-INFRA-DEMOGITEA/REPLICATION_SETUP.md](https://github.com/andreaendigital/tf-infra-demoGitea/blob/main/REPLICATION_SETUP.md) - MySQL replication setup

---

## ✅ Checklist Before Failover

- [ ] Azure MySQL is replicating from AWS (verify with `SHOW SLAVE STATUS`)
- [ ] VPN tunnel is active and healthy
- [ ] Jenkins pipeline has been tested successfully
- [ ] Azure credentials are configured in Jenkins
- [ ] SSH keys are accessible to Jenkins
- [ ] MySQL admin password is in Jenkins credentials
- [ ] Team is notified of impending failover
- [ ] DNS update procedure is documented
- [ ] Rollback plan is prepared

---

**Last Updated**: December 11, 2025  
**Author**: Andrea Beltrán (@andreaendigital)
