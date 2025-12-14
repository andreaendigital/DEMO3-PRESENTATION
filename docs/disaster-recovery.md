# Disaster Recovery Manual

![Status](https://img.shields.io/badge/status-production-success.svg)
![RTO](https://img.shields.io/badge/RTO-20%20minutes-green.svg)
![RPO](https://img.shields.io/badge/RPO-%3C%201%20second-green.svg)

---

!!! danger ""
    <div align="center">
    <h1 style="color: #E74C3C; font-size: 2.5em; margin: 0.5em 0; font-weight: 700;">
    🚨 DISASTER RECOVERY MANUAL
    </h1>
    </div>

## Disaster Scenario: AWS Complete Outage

!!! warning "Critical Situation"
    **Azure MySQL replica stops receiving binlogs** (last replication: moment of failure)

### Recovery Timeline

<div style="border: 1px solid #ddd; padding: 30px; height: 600px; overflow: auto; background: #fff; font-family: 'Segoe UI', Arial, sans-serif;">
<h3 style="text-align: center; margin-bottom: 30px; color: #333; font-weight: 600;">DISASTER RECOVERY TIMELINE</h3>

<!-- Legend -->
<div style="display: flex; justify-content: center; margin-bottom: 20px; gap: 20px; font-size: 12px;">
  <div style="display: flex; align-items: center;"><div style="width: 15px; height: 15px; background: #666; margin-right: 5px;"></div>Task</div>
  <div style="display: flex; align-items: center;"><div style="width: 0; height: 0; border-left: 8px solid transparent; border-right: 8px solid transparent; border-bottom: 12px solid #333; margin-right: 5px;"></div>Milestone</div>
  <div style="display: flex; align-items: center;"><div style="width: 15px; height: 2px; background: #999; margin-right: 5px;"></div>Dependency</div>
</div>

<!-- Time Scale -->
<div style="display: flex; margin-bottom: 20px; padding-left: 200px; border-bottom: 2px solid #333;">
  <div style="width: 60px; text-align: center; font-size: 12px; color: #666; border-right: 1px solid #ddd; padding-bottom: 5px;">0 min</div>
  <div style="width: 60px; text-align: center; font-size: 12px; color: #666; border-right: 1px solid #ddd; padding-bottom: 5px;">5 min</div>
  <div style="width: 60px; text-align: center; font-size: 12px; color: #666; border-right: 1px solid #ddd; padding-bottom: 5px;">10 min</div>
  <div style="width: 60px; text-align: center; font-size: 12px; color: #666; border-right: 1px solid #ddd; padding-bottom: 5px;">15 min</div>
  <div style="width: 60px; text-align: center; font-size: 12px; color: #666; border-right: 1px solid #ddd; padding-bottom: 5px;">20 min</div>
  <div style="width: 60px; text-align: center; font-size: 12px; color: #666; border-right: 1px solid #ddd; padding-bottom: 5px;">25 min</div>
  <div style="width: 60px; text-align: center; font-size: 12px; color: #666; padding-bottom: 5px;">30 min</div>
</div>

<!-- Detection Phase -->
<div style="display: flex; align-items: center; margin-bottom: 35px; height: 80px; background: #fafafa;">
  <div style="width: 180px; padding-right: 20px; text-align: right;">
    <strong style="color: #333;">Detection</strong><br>
    <span style="font-size: 12px; color: #666;">AWS Outage & Alerts</span><br>
    <span style="font-size: 11px; color: #999;">Priority: Critical</span>
  </div>
  <div style="position: relative; width: 420px; height: 40px; background: #f5f5f5; border: 1px solid #ddd;">
    <!-- Grid lines -->
    <div style="position: absolute; left: 60px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 120px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 180px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 240px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 300px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 360px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    
    <div style="position: absolute; left: 0; width: 72px; height: 38px; background: linear-gradient(to right, #e8e8e8 80%, #d0d0d0 100%); border-right: 1px solid #ccc; display: flex; align-items: center; justify-content: center; font-size: 11px; color: #333; font-weight: 500;">0-6 min</div>
    <!-- Milestone -->
    <div style="position: absolute; left: 72px; top: 15px; width: 0; height: 0; border-left: 6px solid transparent; border-right: 6px solid transparent; border-bottom: 10px solid #333;"></div>
  </div>
</div>

<!-- Decision Phase -->
<div style="display: flex; align-items: center; margin-bottom: 35px; height: 80px;">
  <div style="width: 180px; padding-right: 20px; text-align: right;">
    <strong style="color: #333;">Decision</strong><br>
    <span style="font-size: 12px; color: #666;">Analysis & Failover</span><br>
    <span style="font-size: 11px; color: #999;">Depends on: Detection</span>
  </div>
  <div style="position: relative; width: 420px; height: 40px; background: #f5f5f5; border: 1px solid #ddd;">
    <!-- Grid lines -->
    <div style="position: absolute; left: 60px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 120px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 180px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 240px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 300px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 360px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    
    <!-- Dependency arrow -->
    <div style="position: absolute; left: 50px; top: 18px; width: 22px; height: 2px; background: #999;"></div>
    <div style="position: absolute; left: 70px; top: 16px; width: 0; height: 0; border-left: 6px solid #999; border-top: 3px solid transparent; border-bottom: 3px solid transparent;"></div>
    
    <div style="position: absolute; left: 72px; width: 24px; height: 38px; background: linear-gradient(to right, #d8d8d8 80%, #c0c0c0 100%); border-right: 1px solid #ccc; display: flex; align-items: center; justify-content: center; font-size: 10px; color: #333; font-weight: 500;">6-8</div>
    <!-- Milestone -->
    <div style="position: absolute; left: 96px; top: 15px; width: 0; height: 0; border-left: 6px solid transparent; border-right: 6px solid transparent; border-bottom: 10px solid #333;"></div>
  </div>
</div>

<!-- Recovery Phase -->
<div style="display: flex; align-items: center; margin-bottom: 35px; height: 80px; background: #fafafa;">
  <div style="width: 180px; padding-right: 20px; text-align: right;">
    <strong style="color: #333;">Recovery</strong><br>
    <span style="font-size: 12px; color: #666;">Infrastructure Deploy</span><br>
    <span style="font-size: 11px; color: #999;">Resources: 2 Engineers</span>
  </div>
  <div style="position: relative; width: 420px; height: 40px; background: #f5f5f5; border: 1px solid #ddd;">
    <!-- Grid lines -->
    <div style="position: absolute; left: 60px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 120px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 180px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 240px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 300px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 360px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    
    <!-- Dependency arrow -->
    <div style="position: absolute; left: 74px; top: 18px; width: 22px; height: 2px; background: #999;"></div>
    <div style="position: absolute; left: 94px; top: 16px; width: 0; height: 0; border-left: 6px solid #999; border-top: 3px solid transparent; border-bottom: 3px solid transparent;"></div>
    
    <div style="position: absolute; left: 96px; width: 144px; height: 38px; background: linear-gradient(to right, #c8c8c8 70%, #b0b0b0 100%); border-right: 1px solid #ccc; display: flex; align-items: center; justify-content: center; font-size: 11px; color: #333; font-weight: 500;">8-20 min</div>
    <!-- Progress indicator -->
    <div style="position: absolute; left: 96px; bottom: 2px; width: 100px; height: 4px; background: #4CAF50;"></div>
    <!-- Milestone -->
    <div style="position: absolute; left: 240px; top: 15px; width: 0; height: 0; border-left: 6px solid transparent; border-right: 6px solid transparent; border-bottom: 10px solid #333;"></div>
  </div>
</div>

<!-- Verification Phase -->
<div style="display: flex; align-items: center; margin-bottom: 35px; height: 80px;">
  <div style="width: 180px; padding-right: 20px; text-align: right;">
    <strong style="color: #333;">Verification</strong><br>
    <span style="font-size: 12px; color: #666;">MySQL & DNS Update</span><br>
    <span style="font-size: 11px; color: #999;">Final Phase</span>
  </div>
  <div style="position: relative; width: 420px; height: 40px; background: #f5f5f5; border: 1px solid #ddd;">
    <!-- Grid lines -->
    <div style="position: absolute; left: 60px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 120px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 180px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 240px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 300px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    <div style="position: absolute; left: 360px; top: 0; width: 1px; height: 100%; background: #eee;"></div>
    
    <!-- Dependency arrow -->
    <div style="position: absolute; left: 218px; top: 18px; width: 22px; height: 2px; background: #999;"></div>
    <div style="position: absolute; left: 238px; top: 16px; width: 0; height: 0; border-left: 6px solid #999; border-top: 3px solid transparent; border-bottom: 3px solid transparent;"></div>
    
    <div style="position: absolute; left: 240px; width: 120px; height: 38px; background: linear-gradient(to right, #b8b8b8 80%, #a0a0a0 100%); display: flex; align-items: center; justify-content: center; font-size: 11px; color: #333; font-weight: 500;">20-30 min</div>
    <!-- Final milestone -->
    <div style="position: absolute; left: 360px; top: 15px; width: 0; height: 0; border-left: 6px solid transparent; border-right: 6px solid transparent; border-bottom: 10px solid #2E7D32;"></div>
  </div>
</div>

</div>
!!! warning ""
    <div align="center">
    <h2 style="color: #F39C12; font-size: 1.8em; margin: 0.5em 0; font-weight: 600;">
    ⚡ FAILOVER PROCEDURE
    </h2>
    </div>

=== "🔍 T+0-6 min: Detection"
    • Outage Detection
    
    • ❌ AWS services stop responding
    
    • 🔔 Monitoring alerts triggered
    
    • 📧 Notifications sent (Email, Slack, SMS)

=== "🎯 T+6-8 min: Decision"
    • Analysis & Decision
    
    • ✅ Confirm AWS outage scope
    
    • ✅ Verify Azure MySQL replica health
    
    • 🎯 **DECISION: Failover to Azure**
    
    • Trigger Recovery
    
    ```bash
    DEPLOYMENT_MODE: failover
    APPLY_TERRAFORM: true
    DEPLOY_ANSIBLE: true
    ```

=== "🚀 T+8-20 min: Deployment"
    • Infrastructure Deployment
    
    • 🏗️ Terraform: VM + Load Balancer + Network (7 min)
    
    • 📦 Ansible: Gitea installation & configuration (3 min)
    
    • ⏱️ Total deployment time: ~10 minutes

=== "✅ T+20-30 min: Activation"
    • Service Activation
    
    • 🗄️ Promote MySQL replica to master
    
    • 🌐 Verify Gitea service functionality
    
    • 🔄 Update DNS to Azure Load Balancer
    
    • 📢 Notify stakeholders of recovery completion

---

!!! info ""
    <div align="center">
    <h2 style="color: #3498DB; font-size: 1.8em; margin: 0.5em 0; font-weight: 600;">
    🔧 TECHNICAL ARCHITECTURE
    </h2>
    </div>

=== "Database Replication"
    **MySQL 8.0 Master-Replica Setup**
    
    ```sql
    -- AWS RDS (Master)
    [mysqld]
    server_id = 1
    log_bin = mysql-bin
    binlog_format = ROW
    
    -- Azure MySQL (Replica)
    [mysqld]
    server_id = 2
    relay_log = relay-bin
    read_only = 1
    ```
    
    **Key Features:**
    
    - ✅ **ROW Format**: Precise row-level replication
    - ✅ **Real-time**: < 1 second replication lag
    - ✅ **Data Safety**: Exact data replication for failover

=== "Network Connectivity"
    **VPN Site-to-Site IPsec**
    
    ```hcl
    # Cross-cloud VPN connection
    resource "aws_vpn_connection" "azure" {
      type = "ipsec.1"
      static_routes_only = true
    }
    
    resource "azurerm_virtual_network_gateway_connection" "aws" {
      type = "IPsec"
      shared_key = var.vpn_shared_key
    }
    ```
    
    **Security Features:**
    
    - ✅ **Encryption**: AES-256 for all cross-cloud traffic
    - ✅ **Network Isolation**: Private subnets (10.0.0.0/16 ↔ 10.1.0.0/16)
    - ✅ **Redundancy**: Dual tunnel configuration

---

!!! example ""
    <div align="center">
    <h2 style="color: #9B59B6; font-size: 1.8em; margin: 0.5em 0; font-weight: 600;">
    🛠️ TECHNICAL CHALLENGES
    </h2>
    </div>

=== "💰 Challenge 1: AWS Free Tier Limitations"
    **Issue:** Free Tier blocks `backup_retention_period >= 1` required for binlog
    
    **Solutions Tested:**
    
    | Solution | Result |
    |----------|--------|
    | RDS with backup_retention=1 | ❌ Free Tier restriction |
    | Manual MySQL on EC2 | ⚠️ Works, loses RDS benefits |
    | Upgrade to db.t3.small | ✅ Works, +$30/month |
    
    **Resolution:**
    - **Production**: RDS paid tier for full features
    - **Demo**: EC2 MySQL for cost optimization

=== "🔐 Challenge 2: SSH ProxyJump Configuration"
    **Issue:** Private MySQL VM requires proxy access for Ansible
    
    **Architecture:**
    ```
    Jenkins → Gitea VM (Public IP) → MySQL VM (Private IP)
    ```
    
    **Solution:**
    ```ini
    [azure:vars]
    ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p azureuser@<PUBLIC_IP>"'
    ```

---

!!! success ""
    <div align="center">
    <h2 style="color: #27AE60; font-size: 1.8em; margin: 0.5em 0; font-weight: 600;">
    📊 RECOVERY METRICS
    </h2>
    </div>

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| **RTO (Recovery Time)** | < 30 min | 20 min | ✅ **Met** |
| **RPO (Data Loss)** | < 5 min | < 1 sec | ✅ **Exceeded** |
| **Data Integrity** | 100% | 100% | ✅ **Guaranteed** |
| **Automation Level** | 80% | 90% | ✅ **Exceeded** |

---

*Last Updated: {{ git_revision_date_localized }}*