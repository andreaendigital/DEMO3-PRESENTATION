# Gitea Multi-Cloud Disaster Recovery Infrastructure

![Status](https://img.shields.io/badge/status-production-success.svg)
![AWS](https://img.shields.io/badge/cloud-AWS-orange.svg)
![Azure](https://img.shields.io/badge/cloud-Azure-blue.svg)
![Infrastructure](https://img.shields.io/badge/IaC-Terraform-purple.svg)
![Automation](https://img.shields.io/badge/config-Ansible-red.svg)

## Resumen Ejecutivo

Este proyecto implementa una **arquitectura multi-nube de alta disponibilidad** para Gitea (servicio Git self-hosted) con capacidades de disaster recovery mediante replicación MySQL entre AWS y Azure. La solución demuestra prácticas modernas de DevOps, Infrastructure as Code (IaC), CI/CD automatizado, y estrategias de failover cross-cloud.

---

## 🏗️ Arquitectura General del Sistema

### Vista de Alto Nivel: Multi-Cloud Infrastructure

```mermaid
graph TB
    subgraph Jenkins["🔧 JENKINS CI/CD SERVER (Control Plane)"]
        JenkinsAWS["Pipeline AWS<br/>(2 Capas: Terraform → Ansible)"]
        JenkinsAzure["Pipeline Azure<br/>(3 Capas: Terraform → Outputs → Ansible)"]
    end

    subgraph AWS["☁️ AWS REGION (us-east-1)<br/>PRIMARY SITE"]
        subgraph VPC["VPC 10.0.0.0/16"]
            EC2["EC2 Instance<br/>t3.small<br/>Gitea:3000"]
            RDS["RDS MySQL<br/>db.t3.micro<br/>🔴 MASTER<br/>Binlog: ON"]
            ALB["Application<br/>Load Balancer<br/>HTTP 80→3000"]
            VPNGatewayAWS["VPN Gateway<br/>IPsec Tunnel"]
        end
    end

    subgraph Azure["☁️ AZURE REGION (East US)<br/>DISASTER RECOVERY SITE"]
        subgraph VNet["VNet 10.1.0.0/16"]
            VMGitea["VM Gitea<br/>Standard_B2s<br/>Ubuntu 22.04<br/>Gitea:3000"]
            VMMySQL["VM MySQL<br/>Standard_B1ms<br/>🟢 REPLICA<br/>Replication: Active"]
            LB["Azure<br/>Load Balancer<br/>HTTP 80→3000"]
            VPNGatewayAzure["VPN Gateway<br/>IPsec Tunnel"]
        end
    end

    JenkinsAWS -->|Deploy| AWS
    JenkinsAzure -->|Deploy| Azure

    EC2 --> RDS
    ALB --> EC2
    VMGitea --> VMMySQL
    LB --> VMGitea

    RDS -.->|MySQL Replication<br/>via VPN| VMMySQL
    VPNGatewayAWS <-.->|Site-to-Site<br/>IPsec Tunnel| VPNGatewayAzure

    style RDS fill:#ff6b6b
    style VMMySQL fill:#51cf66
    style Jenkins fill:#748ffc
    style AWS fill:#ffd43b
    style Azure fill:#4dabf7
```

### Arquitectura Detallada: AWS Infrastructure

```mermaid
graph TB
    subgraph "AWS Infrastructure (10.0.0.0/16)"
        subgraph "Public Subnets (Multi-AZ)"
            EC2["EC2 Instance<br/>Amazon Linux 2<br/>IP: Dynamic<br/>Port: 3000"]
            ALB["Application Load Balancer<br/>External<br/>HTTP: 80 → 3000"]
        end

        subgraph "Private Subnets (Multi-AZ)"
            RDS["RDS MySQL 8.0<br/>Endpoint: *.rds.amazonaws.com<br/>Port: 3306<br/>Backup Retention: 7 days<br/>Binlog Format: ROW"]
        end

        subgraph "Security"
            SGApp["Security Group (App)<br/>Inbound: 22, 80, 3000<br/>Outbound: All"]
            SGRDS["Security Group (RDS)<br/>Inbound: 3306 from VPC<br/>Outbound: All"]
        end

        subgraph "Networking"
            IGW["Internet Gateway"]
            RT["Route Tables<br/>Public: 0.0.0.0/0 → IGW<br/>Private: Internal only"]
            VPNGW["VPN Gateway<br/>BGP ASN: 65000<br/>Tunnels: 2 (Active-Standby)"]
        end

        subgraph "Storage"
            S3["S3 Bucket<br/>infracar-terraform-state<br/>Purpose: Terraform Backend"]
        end
    end

    Internet["🌐 Internet"] --> IGW
    IGW --> ALB
    ALB --> EC2
    EC2 --> RDS

    SGApp -.- EC2
    SGRDS -.- RDS

    VPNGW -.->|Static Routes<br/>10.1.0.0/16| AzureVPN["Azure VPN Gateway"]

    style RDS fill:#ff6b6b,stroke:#c92a2a,stroke-width:3px
    style VPNGW fill:#ffd43b,stroke:#f59f00,stroke-width:2px
```

### Arquitectura Detallada: Azure Infrastructure

```mermaid
graph TB
    subgraph "Azure Infrastructure (10.1.0.0/16)"
        subgraph "Public Subnet (10.1.0.0/24)"
            VMGitea["Gitea VM<br/>Ubuntu 22.04<br/>Public IP: 40.71.214.30<br/>Port: 3000"]
            VMMySQLJump["MySQL VM (via Jump)<br/>Ubuntu 22.04<br/>Private IP: 10.1.1.4<br/>Port: 3306<br/>Accessible via SSH ProxyJump"]
            LB["Azure Load Balancer<br/>Public IP: 172.191.115.230<br/>HTTP: 80 → 3000"]
        end

        subgraph "Security"
            NSGGitea["NSG (Gitea)<br/>Inbound: 22, 80, 3000<br/>Outbound: All"]
            NSGMySQL["NSG (MySQL)<br/>Inbound: 22 (from Gitea), 3306<br/>Outbound: All"]
        end

        subgraph "Networking"
            VNetGW["VPN Gateway<br/>Type: VpnGw1<br/>VPN Type: RouteBased<br/>Public IP: Assigned"]
            LocalGW["Local Network Gateway<br/>AWS VPC: 10.0.0.0/16<br/>Connection: Site-to-Site"]
        end

        subgraph "Storage"
            StorageAccount["Storage Account<br/>tfstate-gitea-demo<br/>Purpose: Terraform Backend"]
        end
    end

    Internet["🌐 Internet"] --> LB
    LB --> VMGitea
    VMGitea -->|SSH Jump Host| VMMySQLJump

    NSGGitea -.- VMGitea
    NSGMySQL -.- VMMySQLJump

    VNetGW <-.->|IPsec Tunnel<br/>Shared Key<br/>Routes: 10.0.0.0/16| AWSVPN["AWS VPN Gateway"]

    AWSRDS["AWS RDS MySQL<br/>Master"] -.->|MySQL Replication<br/>User: repl_azure<br/>Binlog Streaming| VMMySQLJump

    style VMMySQLJump fill:#51cf66,stroke:#2f9e44,stroke-width:3px
    style VNetGW fill:#4dabf7,stroke:#1971c2,stroke-width:2px
    style VMGitea fill:#fab005,stroke:#f59f00,stroke-width:2px
```

### Flujo de Replicación MySQL (AWS → Azure)

```mermaid
sequenceDiagram
    participant App as Gitea App (AWS)
    participant Master as RDS MySQL (Master)
    participant VPN as VPN Tunnel (IPsec)
    participant Replica as MySQL VM (Replica)
    participant AppAzure as Gitea App (Azure)

    Note over Master: Binlog Format: ROW<br/>Backup Retention: 7 days

    App->>Master: INSERT/UPDATE/DELETE<br/>queries
    Master->>Master: Write to binlog<br/>(mysql-bin.000001)

    Note over VPN: Site-to-Site Tunnel<br/>Shared Key: GitDemoSecureKey2025!

    Master->>VPN: Stream binlog events<br/>via port 3306
    VPN->>Replica: Forward binlog events<br/>(encrypted)

    Replica->>Replica: Apply SQL statements<br/>from binlog
    Replica->>Replica: Update Seconds_Behind_Master<br/>(target: < 1s)

    Note over Replica: SHOW SLAVE STATUS<br/>Slave_IO_Running: Yes<br/>Slave_SQL_Running: Yes

    AppAzure->>Replica: SELECT queries<br/>(read-only)
    Replica-->>AppAzure: Return replicated data

    Note over Master,Replica: Replication Lag: < 1 segundo<br/>Asynchronous streaming
```

### Arquitectura de Red con SSH Jump Host (Azure)

```mermaid
graph LR
    subgraph External["🌐 External Network"]
        Jenkins["Jenkins Server"]
        Developer["Developer Laptop"]
    end

    subgraph Azure["Azure VNet (10.1.0.0/16)"]
        subgraph PublicSubnet["Public Subnet"]
            GiteaVM["Gitea VM<br/>Public IP: 40.71.214.30<br/>SSH: 22"]
        end

        subgraph PrivateZone["Private Zone (No Public IP)"]
            MySQLVM["MySQL VM<br/>Private IP: 10.1.1.4<br/>SSH: 22<br/>MySQL: 3306"]
        end
    end

    Jenkins -->|"1. SSH Direct<br/>ssh azureuser@40.71.214.30"| GiteaVM
    Developer -->|"2. SSH Direct<br/>ssh azureuser@40.71.214.30"| GiteaVM

    Jenkins -->|"3. SSH ProxyJump<br/>ssh -J azureuser@40.71.214.30<br/>azureuser@10.1.1.4"| MySQLVM
    Developer -->|"4. SSH ProxyJump<br/>-o ProxyCommand=..."| MySQLVM

    GiteaVM -.->|"5. Internal Routing<br/>No Internet required"| MySQLVM

    style GiteaVM fill:#fab005,stroke:#f59f00,stroke-width:2px
    style MySQLVM fill:#51cf66,stroke:#2f9e44,stroke-width:2px
    style PrivateZone fill:#e9ecef,stroke:#868e96,stroke-width:2px,stroke-dasharray: 5 5
```

### Deployment Modes en Azure

```mermaid
graph TB
    Start["Pipeline Trigger<br/>DEPLOYMENT_MODE Parameter"]

    Start --> Decision{Deployment<br/>Mode?}

    Decision -->|full-stack| FullStack["Deploy Complete Stack"]
    Decision -->|replica-only| ReplicaOnly["Deploy MySQL Only"]
    Decision -->|failover| Failover["Restore Application"]

    subgraph "Full-Stack Mode"
        FullStack --> FSGitea["✅ Deploy Gitea VM<br/>(Public IP)"]
        FSGitea --> FSMySQL["✅ Deploy MySQL VM<br/>(Private IP)"]
        FSMySQL --> FSLB["✅ Deploy Load Balancer"]
        FSLB --> FSAnsible["✅ Run Ansible<br/>(Both VMs)"]
    end

    subgraph "Replica-Only Mode"
        ReplicaOnly --> RODestroy["❌ Destroy Gitea VM"]
        RODestroy --> RODestroy2["❌ Destroy Load Balancer"]
        RODestroy2 --> ROMySQL["✅ Keep MySQL VM<br/>(Replication Active)"]
        ROMySQL --> ROVPN["✅ Activate VPN Gateway"]
        ROVPN --> ROAnsible["✅ Run Ansible<br/>(MySQL only)"]
    end

    subgraph "Failover Mode"
        Failover --> FOGitea["✅ Deploy Gitea VM<br/>(New/Restored)"]
        FOGitea --> FOMySQL["✅ Use Existing MySQL VM<br/>(Promoted to Primary)"]
        FOMySQL --> FOLB["✅ Deploy Load Balancer"]
        FOLB --> FOAnsible["✅ Run Ansible<br/>(Gitea only)"]
        FOAnsible --> FOPromotion["🔄 Promote MySQL<br/>STOP SLAVE<br/>RESET SLAVE ALL"]
    end

    FSAnsible --> End["✅ Deployment Complete"]
    ROAnsible --> End
    FOPromotion --> End

    style FullStack fill:#4dabf7
    style ReplicaOnly fill:#ffd43b
    style Failover fill:#ff6b6b
```

---
