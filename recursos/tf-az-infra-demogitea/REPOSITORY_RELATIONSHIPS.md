# Gitea Multi-Cloud Architecture - Repository Relationships

This document explains how the four Gitea repositories work together to create a complete multi-cloud infrastructure with automatic failover capability between AWS and Azure.

## 📊 Repository Overview

| Repository                | Cloud | Type           | Purpose                                    |
| ------------------------- | ----- | -------------- | ------------------------------------------ |
| **tf-infra-demoGitea**    | AWS   | Terraform IaC  | Provisions AWS infrastructure (Primary)    |
| **ansible-demoGitea**     | AWS   | Ansible Config | Deploys/configures Gitea on AWS EC2        |
| **tf-az-infra-demoGitea** | Azure | Terraform IaC  | Provisions Azure infrastructure (Failover) |
| **ansible-az-demoGitea**  | Azure | Ansible Config | Deploys/configures Gitea on Azure VM       |

## 🏗️ Complete Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         GITEA MULTI-CLOUD ARCHITECTURE                              │
│                     High Availability with Database Replication                     │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────┐         ┌──────────────────────────────────┐
│       AWS (Primary Site)         │         │     Azure (Failover Site)        │
│      Region: us-east-1           │         │      Region: East US             │
│      VPC: 10.0.0.0/16            │         │      VNet: 10.1.0.0/16           │
└──────────────────────────────────┘         └──────────────────────────────────┘
               │                                          │
               │                                          │
┏━━━━━━━━━━━━━▼━━━━━━━━━━━━━┓         ┏━━━━━━━━━━━━━▼━━━━━━━━━━━━━┓
┃  1️⃣  TERRAFORM (AWS)      ┃         ┃  3️⃣  TERRAFORM (Azure)    ┃
┃  tf-infra-demoGitea       ┃◄────────┃  tf-az-infra-demoGitea    ┃
┃                           ┃  VPN    ┃                           ┃
┃  Creates:                 ┃ Gateway ┃  Creates:                 ┃
┃  • VPC + Subnets          ┃  IPsec  ┃  • VNet + Subnets         ┃
┃  • EC2 (t3.small)         ┃ Tunnel  ┃  • VM (Standard_B2s)      ┃
┃  • RDS MySQL (Master)     ┃◄───────►┃  • MySQL Flex (Replica)   ┃
┃  • Application LB         ┃         ┃  • Load Balancer          ┃
┃  • Security Groups        ┃         ┃  • Network Security Group ┃
┃  • VPN Gateway            ┃         ┃  • VPN Gateway            ┃
┃                           ┃         ┃                           ┃
┃  Outputs:                 ┃         ┃  Outputs:                 ┃
┃  ✓ ec2_public_ip          ┃         ┃  ✓ vm_public_ip           ┃
┃  ✓ rds_endpoint           ┃         ┃  ✓ mysql_server_host      ┃
┃  ✓ alb_dns_name           ┃         ┃  ✓ lb_public_ip           ┃
┃  ✓ vpn_tunnel_ip          ┃         ┃  ✓ vpn_gateway_ip         ┃
┗━━━━━━━━━━━━━┯━━━━━━━━━━━━━┛         ┗━━━━━━━━━━━━━┯━━━━━━━━━━━━━┛
               │                                          │
               │ Outputs feed Ansible                     │ Outputs feed Ansible
               │                                          │
┏━━━━━━━━━━━━━▼━━━━━━━━━━━━━┓         ┏━━━━━━━━━━━━━▼━━━━━━━━━━━━━┓
┃  2️⃣  ANSIBLE (AWS)        ┃         ┃  4️⃣  ANSIBLE (Azure)      ┃
┃  ansible-demoGitea        ┃         ┃  ansible-az-demoGitea     ┃
┃                           ┃         ┃                           ┃
┃  Configures:              ┃         ┃  Configures:              ┃
┃  • Install Gitea binary   ┃         ┃  • Install Gitea binary   ┃
┃  • Configure app.ini      ┃         ┃  • Configure app.ini      ┃
┃  • MySQL connection       ┃         ┃  • MySQL connection       ┃
┃  • Systemd service        ┃         ┃  • Systemd service        ┃
┃  • User/permissions       ┃         ┃  • User/permissions       ┃
┃                           ┃         ┃                           ┃
┃  Inventory:               ┃         ┃  Inventory:               ┃
┃  • Dynamic (from TF)      ┃         ┃  • Static (manual)        ┃
┃  • Host: infraGitea       ┃         ┃  • Host: azureGitea       ┃
┗━━━━━━━━━━━━━┯━━━━━━━━━━━━━┛         ┗━━━━━━━━━━━━━┯━━━━━━━━━━━━━┛
               │                                          │
               │ Deploys                                  │ Deploys
               ▼                                          ▼
┌──────────────────────────────────┐         ┌──────────────────────────────────┐
│   🚀 Gitea Application (AWS)     │         │   🚀 Gitea Application (Azure)   │
│                                  │         │                                  │
│   EC2: 54.123.45.67             │         │   VM: 20.98.76.54               │
│   Port: 3000 → ALB → 80         │         │   Port: 3000 → LB → 80          │
│   Status: 🟢 ACTIVE (Primary)    │         │   Status: 🟡 STANDBY (Failover) │
└──────────────────────────────────┘         └──────────────────────────────────┘
               │                                          │
               │ Writes                                   │ Reads (Replica)
               ▼                                          ▼
┌──────────────────────────────────┐         ┌──────────────────────────────────┐
│   💾 RDS MySQL (Master)          │         │   💾 MySQL Flexible (Replica)    │
│   mydb.abc.rds.amazonaws.com     │─────────▶   mysql-gitea.mysql.azure.com   │
│   Port: 3306                     │ Binlog  │   Port: 3306                     │
│   Status: 🟢 PRIMARY              │ Repl    │   Status: 🔄 REPLICATING         │
└──────────────────────────────────┘         └──────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            🔄 DATABASE REPLICATION                                  │
│                                                                                     │
│   AWS RDS (Master) ──────────[MySQL Binlog]──────────▶ Azure MySQL (Replica)       │
│                                                                                     │
│   • Replication User: repl_azure                                                   │
│   • Connection: Through VPN IPsec tunnel (secure)                                  │
│   • Direction: Unidirectional (AWS → Azure)                                        │
│   • Lag: < 1 second (under normal conditions)                                      │
│   • Purpose: Continuous data sync for failover readiness                           │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         🚨 FAILOVER SCENARIO (AWS Down)                             │
│                                                                                     │
│   1. AWS outage detected                                                           │
│   2. Stop replication on Azure MySQL                                               │
│   3. Promote Azure MySQL from replica to standalone                                │
│   4. Update Gitea app.ini to use Azure MySQL                                       │
│   5. Restart Gitea service on Azure VM                                             │
│   6. Update DNS or notify users of new URL                                         │
│   7. Azure site becomes PRIMARY with latest data                                   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 🔗 Repository Relationships

### 1. **tf-infra-demoGitea** (AWS Terraform) → **ansible-demoGitea** (AWS Ansible)

**Relationship Type:** Infrastructure → Configuration

**Flow:**

```
terraform apply (AWS)
    ├─ Creates EC2 instance
    ├─ Creates RDS MySQL
    ├─ Outputs: ec2_public_ip, rds_endpoint
    └─ Triggers: generate_inventory.sh
           └─ Creates inventory.ini with outputs
                 └─ ansible-playbook runs
                       └─ Installs Gitea on EC2
```

**Key Integration Points:**

- Terraform outputs → Ansible variables
- EC2 public IP → `ansible_host`
- RDS endpoint → `mysql_host`
- Security group → Ansible SSH access

**Files involved:**

```
TF-INFRA-DEMOGITEA/infra/outputs.tf
    ↓ (via Jenkinsfile or manual script)
ANSIBLE-DEMOGITEA/generate_inventory.sh
    ↓ generates
ANSIBLE-DEMOGITEA/inventory.ini
    ↓ used by
ANSIBLE-DEMOGITEA/playbook.yml
```

---

### 2. **tf-az-infra-demoGitea** (Azure Terraform) → **ansible-az-demoGitea** (Azure Ansible)

**Relationship Type:** Infrastructure → Configuration

**Flow:**

```
terraform apply (Azure)
    ├─ Creates VM with static public IP
    ├─ Creates MySQL Flexible Server
    ├─ Outputs: vm_public_ip, mysql_server_host
    └─ User manually updates inventory.ini
           └─ ansible-playbook runs
                 └─ Installs Gitea on Azure VM
```

**Key Integration Points:**

- Terraform outputs → Manual inventory configuration
- VM public IP (static) → `ansible_host`
- MySQL FQDN → `mysql_host`
- NSG rules → Ansible SSH access

**Files involved:**

```
TF-AZ-INFRA-DEMOGITEA/infra/outputs.tf
    ↓ (manual copy of values)
ANSIBLE-AZ-DEMOGITEA/inventory.ini
    ↓ used by
ANSIBLE-AZ-DEMOGITEA/playbook.yml
```

**Note:** No dynamic inventory generation - static IP allows one-time manual setup.

---

### 3. **tf-infra-demoGitea** (AWS) ↔ **tf-az-infra-demoGitea** (Azure)

**Relationship Type:** Bidirectional Infrastructure (VPN + Replication)

**Flow:**

```
Phase 1: Deploy Azure first
    terraform apply (Azure)
        └─ Output: vpn_gateway_public_ip = "20.123.45.67"

Phase 2: Configure AWS with Azure VPN IP
    Update AWS terraform.tfvars:
        enable_vpn_gateway = true
        azure_vpn_gateway_ip = "20.123.45.67"

    terraform apply (AWS)
        ├─ Creates VPN Gateway
        ├─ Creates Customer Gateway (Azure IP)
        ├─ Creates VPN Connection (IPsec)
        ├─ Enables RDS binlog
        └─ Outputs: vpn_tunnel_ip

Phase 3: Update Azure with AWS VPN tunnel IP
    Update Azure terraform.tfvars:
        enable_vpn_gateway = true
        aws_vpn_gateway_ip = "54.123.45.67"

    terraform apply (Azure)
        └─ Establishes VPN tunnel

Phase 4: Configure MySQL Replication
    On AWS RDS: CREATE USER 'repl_azure'@'10.1.%'
    On Azure MySQL: CHANGE MASTER TO...
    On Azure MySQL: START SLAVE
```

**Shared Variables:**

```hcl
# Both sides need matching values
vpn_shared_key     = "SameSecureKey123!"
aws_vpc_cidr       = "10.0.0.0/16"  # AWS → Azure
azure_vnet_cidr    = "10.1.0.0/16"  # Azure → AWS
```

---

### 4. **ansible-demoGitea** (AWS) vs **ansible-az-demoGitea** (Azure)

**Relationship Type:** Parallel Configuration (Same purpose, different clouds)

**Similarities:**

- Both install Gitea from binary
- Both configure MySQL connection
- Both set up systemd service
- Both use same role structure: `roles/deploy`

**Differences:**

| Aspect             | AWS (ansible-demoGitea)    | Azure (ansible-az-demoGitea) |
| ------------------ | -------------------------- | ---------------------------- |
| **Inventory Host** | `infraGitea`               | `azureGitea`                 |
| **Inventory Type** | Dynamic (generated)        | Static (manual)              |
| **VM User**        | `ec2-user` (Amazon Linux)  | `azureuser` (Ubuntu)         |
| **MySQL Host**     | RDS endpoint               | MySQL Flexible FQDN          |
| **SSH Key**        | `~/.ssh/aws-gitea-key.pem` | `~/.ssh/azure-gitea-key.pem` |

---

## 📝 Deployment Workflow

### Initial Setup (Both Clouds)

```bash
# Step 1: Deploy AWS (Primary)
cd TF-INFRA-DEMOGITEA/infra
terraform init && terraform apply

# Step 2: Deploy Gitea on AWS
cd ANSIBLE-DEMOGITEA
./generate_inventory.sh
ansible-playbook -i inventory.ini playbook.yml

# ✅ AWS Gitea is now running

# Step 3: Deploy Azure (Failover)
cd TF-AZ-INFRA-DEMOGITEA/infra
terraform init && terraform apply

# Step 4: Configure Ansible inventory for Azure
cd ANSIBLE-AZ-DEMOGITEA
# Edit inventory.ini with Terraform outputs
nano inventory.ini

# Step 5: Deploy Gitea on Azure
ansible-playbook -i inventory.ini playbook.yml

# ✅ Azure Gitea is now running (standby mode)
```

### Enable VPN and Replication

```bash
# Step 6: Get Azure VPN Gateway IP
cd TF-AZ-INFRA-DEMOGITEA/infra
terraform output vpn_gateway_public_ip

# Step 7: Enable VPN on AWS side
cd TF-INFRA-DEMOGITEA/infra
nano terraform.tfvars  # Add Azure VPN IP
terraform apply

# Step 8: Enable VPN on Azure side
cd TF-AZ-INFRA-DEMOGITEA/infra
nano terraform.tfvars  # Add AWS VPN IP
terraform apply

# Step 9: Configure MySQL replication
# See REPLICATION_SETUP.md for detailed steps

# ✅ Replication is now active
```

## 🚨 Failover Procedure (When AWS Fails)

**Scenario:** AWS region becomes unavailable, Gitea on AWS is down.

**Manual Failover Steps:**

```bash
# 1. Verify Azure MySQL has latest data
ssh azureuser@<AZURE_VM_IP>
mysql -h <AZURE_MYSQL_HOST> -u gitea_admin -p
mysql> SHOW SLAVE STATUS\G
# Check: Seconds_Behind_Master = 0

# 2. Stop replication (promote to standalone)
mysql> STOP SLAVE;
mysql> RESET SLAVE ALL;

# 3. Restart Gitea service (already configured for Azure MySQL)
sudo systemctl restart gitea
sudo systemctl status gitea

# 4. Verify Gitea is accessible
curl http://<AZURE_LB_IP>:3000

# 5. Update DNS or notify users
# Point gitea.yourdomain.com → <AZURE_LB_IP>

# ✅ Azure is now PRIMARY with latest data
```

**Automatic Failover (Future Enhancement):**

- Health checks monitor AWS Gitea
- Automation script detects failure
- Script executes failover steps
- DNS automatically updates
- Notifications sent to team

## 📊 Data Flow Summary

```
┌────────────────────────────────────────────────────────────────┐
│                     NORMAL OPERATIONS                          │
└────────────────────────────────────────────────────────────────┘

User → AWS ALB → EC2 Gitea → AWS RDS MySQL (Master)
                                      │
                                      │ Binlog Replication
                                      ├─ Through VPN Tunnel
                                      │ (10.0.0.0/16 ↔ 10.1.0.0/16)
                                      │
                                      ▼
                           Azure MySQL Flexible (Replica)
                                      │
                                      │ Standby Connection
                                      ▼
                           Azure VM Gitea (Standby)
                                      │
                                      ▼
                              Azure Load Balancer

┌────────────────────────────────────────────────────────────────┐
│                     FAILOVER MODE                              │
└────────────────────────────────────────────────────────────────┘

User → Azure LB → Azure VM Gitea → Azure MySQL (Promoted to Master)
                                           │
                                           │ Latest replicated data
                                           ▼
                                    Gitea data accessible
```

## 🔧 Variable Mapping Between Repositories

### AWS Terraform → AWS Ansible

| Terraform Output | Ansible Variable | Usage               |
| ---------------- | ---------------- | ------------------- |
| `ec2_public_ip`  | `ansible_host`   | SSH connection      |
| `rds_endpoint`   | `mysql_host`     | Database connection |
| `mysql_dbname`   | `mysql_dbname`   | Database name       |
| `mysql_username` | `mysql_username` | DB user             |

### Azure Terraform → Azure Ansible

| Terraform Output       | Ansible Variable | Usage               |
| ---------------------- | ---------------- | ------------------- |
| `vm_public_ip`         | `ansible_host`   | SSH connection      |
| `mysql_server_host`    | `mysql_host`     | Database connection |
| `mysql_database_name`  | `mysql_dbname`   | Database name       |
| `mysql_admin_username` | `mysql_username` | DB user             |

## 🎯 Key Design Decisions

### Why Different Inventory Methods?

**AWS: Dynamic Inventory**

- Terraform outputs change frequently during development
- Jenkins pipeline automates the process
- `generate_inventory.sh` script bridges Terraform → Ansible

**Azure: Static Inventory**

- VM has static public IP (doesn't change)
- Simpler for manual failover deployment
- One-time configuration after Terraform apply

### Why Separate Repositories?

1. **Separation of Concerns**: Infrastructure (Terraform) vs Configuration (Ansible)
2. **Cloud Isolation**: AWS and Azure code independently versioned
3. **Reusability**: Modules can be reused in other projects
4. **CI/CD**: Different pipelines for different clouds
5. **Team Permissions**: Different teams can manage different clouds

### Why Unidirectional Replication?

- AWS is PRIMARY (production traffic)
- Azure is FAILOVER (disaster recovery)
- Simpler to manage than bidirectional
- Prevents split-brain scenarios
- Clear failover procedure

## 📚 Additional Resources

- **AWS Architecture**: See [TF-INFRA-DEMOGITEA/README.md](https://github.com/andreaendigital/tf-infra-demoGitea)
- **Azure Architecture**: See [TF-AZ-INFRA-DEMOGITEA/README.md](./README.md)
- **Replication Setup**: See [REPLICATION_SETUP.md](https://github.com/andreaendigital/tf-infra-demoGitea/blob/main/REPLICATION_SETUP.md)
- **AWS Ansible**: See [ANSIBLE-DEMOGITEA/README.md](https://github.com/andreaendigital/ansible-demoGitea)
- **Azure Ansible**: See [ANSIBLE-AZ-DEMOGITEA/README.md](https://github.com/andreaendigital/ansible-az-demoGitea)

## 🤔 FAQ

**Q: Can I deploy only AWS or only Azure?**
A: Yes! Each cloud stack is independent. VPN and replication are optional.

**Q: What happens if replication fails?**
A: Azure will have stale data. You'll need to re-sync or restore from backup during failover.

**Q: Can I switch Azure to PRIMARY permanently?**
A: Yes, but you'd need to reconfigure replication direction (Azure → AWS).

**Q: How long does failover take?**
A: Manual: ~5-10 minutes. Automated (future): ~1-2 minutes.

**Q: Do I need both Ansible repos cloned?**
A: Only if deploying both clouds. For single cloud, one Terraform + one Ansible repo is sufficient.

## 📝 License

All repositories: MIT License

## 👤 Author

**Andrea Beltrán**

- GitHub: [@andreaendigital](https://github.com/andreaendigital)
