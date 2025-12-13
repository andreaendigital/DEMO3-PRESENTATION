# Gitea Multi-Cloud Disaster Recovery Infrastructure

![Status](https://img.shields.io/badge/status-production-success.svg)
![AWS](https://img.shields.io/badge/cloud-AWS-orange.svg)
![Azure](https://img.shields.io/badge/cloud-Azure-blue.svg)
![Infrastructure](https://img.shields.io/badge/IaC-Terraform-purple.svg)
![Automation](https://img.shields.io/badge/config-Ansible-red.svg)

---

## Resumen Ejecutivo

Este proyecto implementa una **arquitectura multi-nube de alta disponibilidad** para Gitea (servicio Git self-hosted) con capacidades de disaster recovery mediante replicación MySQL entre AWS y Azure. La solución demuestra prácticas modernas de DevOps, Infrastructure as Code (IaC), CI/CD automatizado, y estrategias de failover cross-cloud con notificación y activación manual.

**Características Principales:**

- Infraestructura como Código (Terraform) en AWS y Azure
- Gestión de Configuración automatizada (Ansible)
- Replicación MySQL unidireccional (AWS → Azure) con lag < 1 segundo
- Túnel VPN Site-to-Site IPsec entre clouds
- Servidores Jenkins independientes por cloud
- Failover manual con notificación automática
- RTO objetivo: ~20 minutos | RPO objetivo: < 1 segundo

---

## Arquitectura de la Solución Multi-Cloud

La solución se compone de **4 repositorios Git independientes** que trabajan de forma coordinada:

| Repositorio               | Cloud | Tipo           | Propósito                                |
| ------------------------- | ----- | -------------- | ---------------------------------------- |
| **tf-infra-demoGitea**    | AWS   | Terraform IaC  | Provisiona infraestructura AWS (Primary) |
| **ansible-demoGitea**     | AWS   | Ansible Config | Despliega/configura Gitea en AWS EC2     |
| **tf-az-infra-demoGitea** | Azure | Terraform IaC  | Provisiona infraestructura Azure (DR)    |
| **ansible-az-demoGitea**  | Azure | Ansible Config | Despliega/configura Gitea en Azure VM    |

**Diagrama de arquitectura completa:**

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
┃  [1] TERRAFORM (AWS)      ┃         ┃  [3] TERRAFORM (Azure)    ┃
┃  tf-infra-demoGitea       ┃◄────────┃  tf-az-infra-demoGitea    ┃
┃                           ┃  VPN    ┃                           ┃
┃  Creates:                 ┃ Gateway ┃  Creates:                 ┃
┃  • VPC + Subnets          ┃  IPsec  ┃  • VNet + Subnets         ┃
┃  • EC2 (t3.small)         ┃ Tunnel  ┃  • VM Gitea (Standard_DC1ds_v3)   ┃
┃  • RDS MySQL (Master)     ┃◄───────►┃  • VM MySQL (Replica)   ┃
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
┃  [2] ANSIBLE (AWS)        ┃         ┃  [4] ANSIBLE (Azure)      ┃
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
┃  • Dynamic (from TF)      ┃         ┃  • Static                 ┃
┃  • Host: infraGitea       ┃         ┃  • Host: azureGitea       ┃
┗━━━━━━━━━━━━━┯━━━━━━━━━━━━━┛         ┗━━━━━━━━━━━━━┯━━━━━━━━━━━━━┛
               │                                          │
               │ Deploys                                  │ Deploys
               ▼                                          ▼
┌──────────────────────────────────┐         ┌──────────────────────────────────┐
│   [APP] Gitea Application (AWS)  │         │   [APP] Gitea Application (Azure)│
│                                  │         │                                  │
│   EC2: 54.123.45.67             │         │   VM: 20.98.76.54               │
│   Port: 3000 → ALB → 80         │         │   Port: 3000 → LB → 80          │
│   Status: [ACTIVE] (Primary)     │         │   Status: [STANDBY] (Failover)   │
└──────────────────────────────────┘         └──────────────────────────────────┘
               │                                          │
               │ Writes                                   │ Reads (Replica)
               ▼                                          ▼
┌──────────────────────────────────┐         ┌──────────────────────────────────┐
│   [DB] RDS MySQL (Master)        │         │   [DB] VM MySQL  (Replica)       │
│   mydb.abc.rds.amazonaws.com     │─────────▶   mysql-gitea.mysql.azure.com   │
│   Port: 3306                     │ Binlog  │   Port: 3306                     │
│   Status: [PRIMARY]              │ Repl    │   Status: [REPLICATING]          │
└──────────────────────────────────┘         └──────────────────────────────────┘
```

### Decisiones de Arquitectura Clave

#### Dos Servidores Jenkins Independientes

**Contexto:** Cada cloud provider requiere credenciales, configuraciones y políticas de acceso específicas.

**Decisión:** Desplegar un servidor Jenkins dedicado en cada cloud (Jenkins AWS + Jenkins Azure) en lugar de un único Jenkins centralizado.

**Justificación:**

- [✓] **Aislamiento de credenciales**: Cada Jenkins solo tiene acceso a su cloud
- [✓] **Autonomía operativa**: Azure puede operar independientemente si AWS falla
- [✓] **Seguridad**: Reducción de superficie de ataque (no hay credenciales cross-cloud en un solo lugar)


#### SSH Jump Host (Bastion) en Azure

**Contexto:** Seguridad de la base de datos MySQL.

MySQL VM sin IP pública, accesible solo vía SSH ProxyJump a través de Gitea VM.

- [✓] **Seguridad**: MySQL no expuesto a Internet
- [✓] **Costo**: No se consume IP pública adicional
- [✓] **Compliance**: Mejor postura de seguridad para auditorías
- [✓] **Complejidad**: Ansible requiere configuración ProxyCommand

**Arquitectura de acceso:**

```
┌──────────────────────────────────────────────────────────────┐
│                 Azure VNet (10.1.0.0/16)                     │
│                                                              │
│   ┌─────────────────────┐         ┌────────────────────┐   │
│   │  Gitea VM           │         │  MySQL VM          │   │
│   │  (Jump Host)        │         │  (Private only)    │   │
│   ├─────────────────────┤         ├────────────────────┤   │
│   │                     │         │                    │   │
│   │ Public IP:          │         │ Public IP: NONE    │   │
│   │   40.71.214.30      │         │                    │   │
│   │                     │         │ Private IP:        │   │
│   │ Private IP:         │         │   10.1.1.4         │   │
│   │   10.1.0.5          │         │                    │   │
│   │                     │         │ Port 22: ✓ (SSH)  │   │
│   │ Port 22: ✓ (SSH)   │         │ Port 3306: ✓       │   │
│   │ Port 3000: ✓ (HTTP)│         │                    │   │
│   └─────────┬───────────┘         └─────────▲──────────┘   │
│             │                               │              │
└─────────────┼───────────────────────────────┼──────────────┘
              │                               │
              │  Internet                     │  Internal
              │  Access                       │  Routing Only
              │                               │
     ┌────────▼────────┐           ┌──────────┴─────────┐
     │  Developer/     │           │  Jump Connection   │
     │  Jenkins        │           │  (ProxyCommand)    │
     │                 │           │                    │
     │  ssh azureuser@ │           │  ssh -J azureuser@ │
     │    40.71.214.30 │           │    40.71.214.30    │
     │                 │           │    azureuser@      │
     │                 │           │    10.1.1.4        │
     └─────────────────┘           └────────────────────┘
        Direct SSH                     ProxyJump SSH
```

#### Replicación MySQL Unidireccional (AWS → Azure)

**Contexto:** Definir flujo de datos entre clouds.

**Decisión:** Replicación master-slave unidireccional de AWS (Master) hacia Azure (Replica).

**Justificación:**

- [✓] **Simplicidad**: Evita conflictos de sincronización bidireccional
- [✓] **Rol claro**: AWS es PRIMARY, Azure es DR
- [✓] **Prevención split-brain**: No hay escrituras simultáneas en ambos clouds

**Flujo de replicación:**

```
┌────────────────────────────────────────────────────────────────┐
│                     DATABASE REPLICATION                       │
└────────────────────────────────────────────────────────────────┘

AWS RDS MySQL (Master)
      │
      │ [Step 1] User operation (INSERT/UPDATE/DELETE)
      │
      ├──→ Write to binlog (mysql-bin.000001)
      │    Format: ROW (row-based replication)
      │
      │ [Step 2] Binlog transmission
      │
      ├──→ Through VPN IPsec Tunnel
      │    (10.0.0.0/16 ↔ 10.1.0.0/16)
      │    Port: 3306 (encrypted)
      │
      ▼
Azure MV MySQL  (Replica)
      │
      │ [Step 3] Replica IO Thread
      │
      ├──→ Receive binlog events
      │    Store in relay-log
      │
      │ [Step 4] Replica SQL Thread
      │
      ├──→ Apply SQL statements
      │    Update Seconds_Behind_Master
      │
      ▼
[REPLICATION ACTIVE]
Lag: < 1 second
```

---

## Flujo Operacional Normal

### AWS Activo + Azure Standby

Durante operaciones normales, la arquitectura opera en modo **híbrido cost-optimized**:

```
┌─────────────────────────────┐     ┌─────────────────────────────┐
│       AWS (PRODUCCIÓN)      │     │   Azure (DB ONLY - Standby) │
├─────────────────────────────┤     ├─────────────────────────────┤
│                             │     │                             │
│  [✓] Users → ALB → EC2      │     │  [X] NO VM                  │
│                  ↓          │     │  [X] NO Load Balancer       │
│           RDS MySQL ────────┼─────┼──→ [✓] MySQL Replica        │
│           (Master)          │ VPN │     (Replicating)           │
│                             │     │                             │
└─────────────────────────────┘     └─────────────────────────────┘
                                                 ▲
                                                 │
                                          Continuous MySQL
                                           Replication
                                           (< 1 sec lag)
```

### Flujo de Datos: Usuario → Aplicación → Base de Datos

**Arquitectura de capas en AWS:**

```
┌────────────────────────────────────────────────────────────────┐
│                     USER REQUEST FLOW                          │
└────────────────────────────────────────────────────────────────┘

[1] User (Developer)
      │
      │ HTTP Request: http://gitea-alb-123.us-east-1.elb.amazonaws.com
      │ Action: git clone, web UI navigation, API call
      │
      ▼
[2] Application Load Balancer (ALB)
      │
      │ Target Group: EC2 instances on port 3000
      │ Health Check: /api/healthz (every 30s)
      │ Listener: HTTP:80 → HTTP:3000
      │
      ▼
[3] EC2 Instance (Gitea Application)
      │
      │ Gitea Binary: /usr/local/bin/gitea
      │ Config: /etc/gitea/app.ini
      │ Service: systemd (gitea.service)
      │ User: git
      │
      ├─ [3a] Read operations (SELECT)
      │   └─→ Fast response from RDS read replica
      │
      ├─ [3b] Write operations (INSERT/UPDATE/DELETE)
      │   └─→ Write to RDS Master
      │        └─→ Binlog generated
      │             └─→ Replicated to Azure
      │
      ▼
[4] RDS MySQL Master
      │
      │ Database: gitea_db
      │ Tables: user, repository, issue, pull_request, etc.
      │ Binlog: mysql-bin.000001 (ROW format)
      │
      └─→ [5] MySQL Replication
            │
            │ VPN Tunnel (10.0.0.0/16 → 10.1.0.0/16)
            │ Port: 3306 (encrypted via IPsec)
            │ User: repl_azure@10.1.%
            │
            ▼
          Azure MySQL Flexible Server (Replica)
            │
            └─ Replica lag: < 1 second
            └─ Data ready for failover
```

### Despliegue con Jenkins:  AWS

**Flujo del pipeline:**

```
[Trigger] Jenkins Build (Manual or Git webhook)
    ↓
[Stage 1: Terraform Apply]
    ├─ terraform init (initialize providers)
    ├─ terraform plan (preview changes)
    ├─ terraform apply -auto-approve (create resources)
    │   ├─ VPC + Subnets
    │   ├─ EC2 Instance (stopped initially)
    │   ├─ RDS MySQL
    │   ├─ Security Groups
    │   └─ ALB + Target Group
    └─ Outputs: ec2_public_ip, rds_endpoint
        ↓
[Stage 2: Generate Inventory]
    ├─ Read Terraform outputs (terraform output -raw)
    ├─ Create inventory.ini dynamically
    ├─ Inject MySQL host, DB name, username
    └─ File ready: ansible/inventory.ini
        ↓
[Stage 3: Ansible Deploy]
    ├─ SSH to EC2 (via inventory.ini)
    ├─ Install dependencies (wget, git, systemd)
    ├─ Download Gitea binary v1.21.5
    ├─ Create git user + directories
    ├─ Render app.ini template (with MySQL credentials)
    ├─ Enable & start gitea.service
    └─ Verify: curl http://localhost:3000
        ↓
[Success] Gitea accessible at ALB URL
```

### Despliegue con Jenkins: Pipeline Azure

**Diferencias clave con AWS:**

- **Deployment modes**: Soporta 3 modos (full-stack, replica-only, failover)


### Modos de Deployment en Azure

Azure soporta **3 modos flexibles** controlados por variable Terraform:

-> Insertar pantallazo de el panel de jenkins y las opcines para deploy

#### Modo 1: FULL-STACK (Desarrollo/Testing)

```
┌──────────────────────────────────────────────┐
│  FULL-STACK MODE                             │
│  Deployment Mode: full-stack                 │
├──────────────────────────────────────────────┤
│                                              │
│  Terraform creates:                          │
│  [✓] Resource Group                          │
│  [✓] Virtual Network + Subnets               │
│  [✓] VM Gitea                                │
│  [✓] VM MySQL                                │
│  [✓] Load Balancer                           │
│  [✓] NSG (Network Security Groups)           │
│  [✓] Public IPs (VM + LB)                    │
│  [✓] VPN Gateway (optional)                  │
│                                              │
│  Ansible configures:                         │
│  [✓] Install Gitea on VM                     │
│  [✓] Install MySQL on MySQL VM               │
│  [✓] Configure replication (if VPN enabled)  │
│                                              │
│  Use case: Development, testing, demos       │
└──────────────────────────────────────────────┘
```

#### Modo 2: REPLICA-ONLY (DR Standby Cost-Optimized)

```
┌──────────────────────────────────────────────┐
│  REPLICA-ONLY MODE                           │
│  Deployment Mode: replica-only               │
├──────────────────────────────────────────────┤
│                                              │
│  Terraform creates:                          │
│  [✓] Resource Group                          │
│  [✓] Virtual Network + Subnets               │
│  [X] NO VM Gitea (destroyed if exists)       │
│  [✓] VM MySQL                                │
│  [X] NO Load Balancer                        │
│  [✓] NSG (MySQL only)                        │
│  [✓] VPN Gateway (REQUIRED)                  │
│                                              │
│  Ansible configures:                         │
│  [✓] MySQL replication from AWS              │
│  [X] NO Gitea deployment                     │
│                                              │
│  Use case: DR standby (production scenario)  │
└──────────────────────────────────────────────┘
```

#### Modo 3: FAILOVER (Emergency Recovery)

```
┌──────────────────────────────────────────────┐
│  FAILOVER MODE                               │
│  Deployment Mode: failover                   │
├──────────────────────────────────────────────┤
│                                              │
│  Terraform creates:                          │
│  [✓] Resource Group (reuse if exists)        │
│  [✓] Virtual Network (reuse if exists)       │
│  [✓] VM Gitea (NEW deployment)               │
│  [✓] VM MySQL (ASSUMES EXISTS with data)     │
│  [✓] Load Balancer (NEW)                     │
│  [✓] Public IPs                              │
│  [X] NO VPN Gateway (not needed)             │
│                                              │
│  Ansible configures:                         │
│  [✓] Install Gitea on new VM                 │
│  [✓] Connect to existing MySQL               │
│  [!] MANUAL: Promote MySQL (STOP SLAVE)      │
│                                              │
│  Use case: AWS down, activate Azure          │
└──────────────────────────────────────────────┘
```

---

## Disaster Recovery y Failover Manual

### Escenario de Desastre: AWS Totalmente Inaccesible


- [!] **Azure MySQL replica deja de recibir nuevos binlogs** (última replicación: momento del fallo)

**Timeline del incidente:**

```
┌─────────────────────────────────────────────────────────────┐
│            AWS OUTAGE DETECTION & RESPONSE                  │
└─────────────────────────────────────────────────────────────┘

T+0 min   [X] AWS us-east-1 outage begins
          ├─ EC2 instances stop responding
          ├─ RDS MySQL connections timeout
          └─ ALB health checks fail

T+3 min   [!] MONITORING SYSTEM DETECTS FAILURE
          ├─ CloudWatch alarms trigger (AWS)
          ├─ External monitoring (Pingdom/UptimeRobot) detects downtime
          ├─ HTTP health check fails: http://aws-gitea.com → TIMEOUT
          └─ NOTIFICATION SENT:
              ├─ Email to ops team
              ├─ Slack/Discord alert
              └─ SMS to on-call engineer

T+6 min   [HUMAN DECISION] On-call engineer reviews:
          ├─ Confirms AWS status page shows regional outage
          ├─ Verifies Azure MySQL replica is healthy
          ├─ Checks Seconds_Behind_Master (should be stable)
          └─ DECISION: Proceed with manual failover to Azure

T+8 min   [MANUAL ACTION] Engineer triggers Jenkins Azure pipeline
          ├─ Access Jenkins Azure server
          ├─ Navigate to: Azure-Gitea-Deployment job
          ├─ Click "Build with Parameters"
          └─ Set parameters:
              ├─ DEPLOYMENT_MODE: failover
              ├─ APPLY_TERRAFORM: true
              ├─ DEPLOY_ANSIBLE: true
              └─ Click [Build]

T+10 min  [TERRAFORM] Azure infrastructure deployment starts
          ├─ Terraform creates VM Gitea (Standard_B2s)
          ├─ Terraform creates Load Balancer
          ├─ Terraform creates Public IP
          ├─ Terraform creates NSG rules
          └─ Duration: ~5-7 minutes

T+17 min  [ANSIBLE] Gitea application deployment
          ├─ SSH to new Azure VM
          ├─ Download Gitea binary
          ├─ Configure app.ini (MySQL host: existing Azure MySQL)
          ├─ Start gitea.service
          └─ Duration: ~3-4 minutes

T+20 min  [MANUAL] Promote Azure MySQL to standalone
          ├─ SSH to Azure VM: ssh azureuser@<VM_IP>
          ├─ Connect to MySQL: mysql -h <MYSQL_HOST> -u admin -p
          ├─ Execute: STOP SLAVE;
          ├─ Execute: RESET SLAVE ALL;
          └─ Verify: SHOW MASTER STATUS;

T+22 min  [VERIFICATION] Confirm Gitea accessibility
          ├─ Test URL: http://<AZURE_LB_IP>:3000
          ├─ Login with test user
          ├─ Clone repository via HTTP
          └─ Verify data integrity (latest commits visible)

T+25 min  [DNS UPDATE] Point domain to Azure (if using custom domain)
          ├─ Update DNS A record: gitea.company.com → <AZURE_LB_IP>
          ├─ TTL propagation: 5-60 minutes
          └─ Notify users of new IP if no custom domain

T+30 min  [COMMUNICATION] Notify stakeholders
          ├─ Email to engineering teams
          ├─ Update status page: "Recovered on Azure"
          ├─ Document incident in runbook
          └─ Schedule post-mortem meeting

[SUCCESS] Azure is now PRIMARY with latest replicated data
          Data loss: < 1 second (last replication before AWS outage)
```


---

## Stack Tecnológico y Desafíos Técnicos

### Tecnologías Utilizadas

#### Database Replication

**MySQL 8.0 - Binlog ROW Format**

```sql
-- Configuración en AWS RDS (Master)
[mysqld]
server_id = 1
log_bin = mysql-bin
binlog_format = ROW          # ← Captura cambios a nivel de fila
binlog_expire_logs_seconds = 604800  # 7 días
max_binlog_size = 100M

-- Configuración en Azure MySQL (Replica)
[mysqld]
server_id = 2
relay_log = relay-bin
read_only = 1                # ← Previene escrituras accidentales
```

**Ventajas de ROW format:**

- [✓] **Precision**: Captura estado exacto de filas modificadas
- [✓] **Consistency**: No depende de funciones no deterministas
- [✓] **Failover safety**: Datos exactos replicados

#### Networking

**VPN Site-to-Site IPsec**

```hcl
# AWS VPN Connection
resource "aws_vpn_connection" "azure" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.azure.id
  type                = "ipsec.1"

  static_routes_only = true

  tunnel1_preshared_key = var.vpn_shared_key  # GitDemoSecureKey2025!

  tags = {
    Name = "AWS-to-Azure-VPN"
  }
}

# Azure VPN Connection
resource "azurerm_virtual_network_gateway_connection" "aws" {
  name                = "azure-to-aws"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.aws.id

  shared_key = var.vpn_shared_key
}
```

**Características:**

- [✓] **Encryption**: AES-256 para todo el tráfico cross-cloud
- [✓] **Static routes**: 10.0.0.0/16 ↔ 10.1.0.0/16
- [✓] **Redundancy**: Dual tunnels (active-standby)

### 5.2 Desafíos Técnicos Enfrentados

#### Desafío 1: AWS Free Tier y Replicación MySQL

**Problema:**

```
Error al habilitar binlog en RDS MySQL (AWS Free Tier):

InvalidParameterCombination: FreeTierRestrictionError
Cannot set backup_retention_period to 1 or greater on db.t3.micro
in Free Tier. Value must be 0.

Razón: Binlog replication requiere backup_retention_period >= 1,
pero Free Tier bloquea esta configuración.
```

**Intentos de solución:**

| Intento | Solución propuesta                    | Resultado                                                                         |
| ------- | ------------------------------------- | --------------------------------------------------------------------------------- |
| 1       | Usar RDS con backup_retention=1       | [X] Error: Free Tier restriction                                                  |
| 2       | Instalar MySQL en EC2 manual          | [~] Funciona, pero pierde beneficios RDS (backups, multi-AZ, parches automáticos) |
| 3       | Upgrade a RDS paid tier (db.t3.small) | [✓] Funciona, pero costo adicional ~$30/mes                                       |
| 4       | Documentar limitación en README       | [✓] Solución temporal para demos                                                  |

**Resolución final:**

- **Para producción**: Usar RDS paid tier (db.t3.small o superior)
- **Para demos/POC**: Documentar limitación, usar EC2 con MySQL manual o demostrar con cuenta no-free-tier

**Lección aprendida:**

```
Free Tier es excelente para aprendizaje básico, pero tiene limitaciones
críticas para arquitecturas avanzadas como replicación cross-cloud.
Siempre revisar restricciones de Free Tier antes de diseñar DR strategies.
```

#### Desafío 2: SSH ProxyJump con Ansible en Azure

**Problema:**

Azure MySQL VM no tiene IP pública (security best practice), pero Ansible necesita conectarse para configurar replicación.

**Arquitectura de acceso:**

```
Laptop/Jenkins ──[SSH]──► Gitea VM (40.71.214.30)
                              │
                              │ [Internal routing]
                              │
                              └──[SSH]──► MySQL VM (10.1.1.4)
                                             └─ No public IP
```

**Solución implementada:**

```ini
# inventory.ini
[azure]
azureMySQL ansible_host=10.1.1.4 ansible_user=azureuser

[azure:vars]
# ProxyCommand: Usa Gitea VM como jump host
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p azureuser@40.71.214.30" -o StrictHostKeyChecking=no'
```



## Resumen Ejecutivo Final

**El proyecto demuestra una arquitectura multi-cloud de disaster recovery completamente funcional con:**

[✓] Arquitectura Multi-Cloud Funcional
[✓] Dos servidores Jenkins independientes
[✓] SH Jump Host sin IP pública en database
[✓] **4 repositorios Git** integrados 
[✓] **2 servidores Jenkins independientes** (uno por cloud, autonomía operativa)  
[✓] **Replicación MySQL cross-cloud** (AWS RDS → Azure MySQL Flexible Server)  
[✓] **VPN Site-to-Site IPsec** (túnel seguro entre VPC 10.0.0.0/16 y VNet 10.1.0.0/16)  
[✓] **3 modos de deployment en azure** (full-stack, replica-only, failover)  
[✓] **RTO: ~20 minutos | RPO: < 1 segundo**  
[✓] **Failover manual con notificación automática** (sistema alerta, operador ejecuta)  


### Mejores Prácticas Implementadas

#### 1. Secrets Management

#### 2. Infrastructure as Code

#### 3. Idempotency

#### 4. Documentation


**Tecnologías:** Terraform, Ansible, Jenkins, MySQL, VPN IPsec, AWS (VPC, EC2, RDS, ALB), Azure (VNet, VM, MV MySQL, Load Balancer)



---

## Recursos 

**Repositorios:**

- [tf-infra-demoGitea](https://github.com/andreaendigital/tf-infra-demoGitea)
- [ansible-demoGitea](https://github.com/andreaendigital/ansible-demoGitea)
- [tf-az-infra-demoGitea](https://github.com/andreaendigital/tf-az-infra-demoGitea)
- [ansible-az-demoGitea](https://github.com/andreaendigital/ansible-az-demoGitea)


---


