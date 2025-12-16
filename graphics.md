REPLICATION FLOW DIAGRAM (Mermaid):

sequenceDiagram
participant User as 👨‍💻 User
participant Gitea as 🖥️ AWS Gitea
participant RDS as 🗄️ AWS RDS<br/>(PRIMARY)
participant VPN as 🔐 VPN Tunnel<br/>(IPsec)
participant AzMySQL as 🗄️ Azure MySQL<br/>(REPLICA)
participant AzGitea as 🖥️ Azure Gitea

    Note over User,AzGitea: NORMAL OPERATION - Data Synchronization

    User->>Gitea: 1️⃣ Git Push (commit code)
    activate Gitea
    Gitea->>RDS: 2️⃣ INSERT INTO repositories
    activate RDS
    RDS->>RDS: 3️⃣ Write to Binlog<br/>mysql-bin.000001:157
    Note over RDS: Binlog Format: ROW<br/>Backup Retention: 7 days

    RDS->>VPN: 4️⃣ Stream Binlog Events<br/>(Encrypted AES-256)
    activate VPN
    VPN->>AzMySQL: 5️⃣ Decrypt & Forward<br/>Binlog Stream
    activate AzMySQL

    AzMySQL->>AzMySQL: 6️⃣ Slave IO Thread<br/>Reads & Writes Relay Log
    AzMySQL->>AzMySQL: 7️⃣ Slave SQL Thread<br/>Applies Changes
    Note over AzMySQL: Slave_IO_Running: Yes<br/>Slave_SQL_Running: Yes<br/>Seconds_Behind_Master: 0

    deactivate AzMySQL
    deactivate VPN
    RDS-->>Gitea: 8️⃣ INSERT Confirmed
    deactivate RDS
    Gitea-->>User: 9️⃣ Push Success ✅
    deactivate Gitea

    Note over User,AzGitea: DATA SYNCHRONIZED - Both clouds have same data

    User->>AzGitea: 🔍 Read Repository (failover test)
    activate AzGitea
    AzGitea->>AzMySQL: SELECT * FROM repositories
    activate AzMySQL
    AzMySQL-->>AzGitea: ✅ Same data as AWS
    deactivate AzMySQL
    AzGitea-->>User: ✅ Repository visible
    deactivate AzGitea

MySQL Replication Configuration

graph LR
subgraph Config["🔧 MySQL Replication Configuration"]
direction TB

        subgraph AWSConfig["AWS RDS Configuration"]
            B1["enable_binlog = true"]
            B2["backup_retention_period = 7"]
            B3["binlog_format = ROW"]
            B4["server_id = 1"]
            B5["Replication User:<br/>repl_azure@10.1.1.x<br/>REPLICATION SLAVE"]
        end

        subgraph AzureConfig["Azure MySQL Configuration"]
            S1["server_id = 2"]
            S2["relay_log enabled"]
            S3["CHANGE MASTER TO:<br/>MASTER_HOST = 10.0.3.x<br/>MASTER_USER = repl_azure<br/>MASTER_PASSWORD = ***<br/>MASTER_LOG_FILE = mysql-bin.000001<br/>MASTER_LOG_POS = 157"]
            S4["START SLAVE;"]
        end
    end

    B1 --> B2
    B2 --> B3
    B3 --> B4
    B4 --> B5
    B5 -.->|Connects via VPN| S3
    S1 --> S2
    S2 --> S3
    S3 --> S4

    style AWSConfig fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
    style AzureConfig fill:#ffcdd2,stroke:#c62828,stroke-width:2px
    style B5 fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    style S3 fill:#bbdefb,stroke:#1565c0,stroke-width:2px

SSH ProxyJump Connection Flow:

sequenceDiagram
participant Dev as 👨‍💻 Developer
participant Gitea as 🖥️ Gitea VM<br/>(Jump Host)
participant MySQL as 🗄️ MySQL VM<br/>(Private)

    Note over Dev,MySQL: Acceso to MySQL via ProxyJump
    Dev->>Gitea: 1️⃣ SSH to Jump Host (Port 22)
    activate Gitea
    Gitea->>MySQL: 2️⃣ SSH Forward to MySQL<br/>(Internal: 10.1.1.X:22)
    activate MySQL
    MySQL-->>Gitea: 3️⃣ MySQL SSH Response
    Gitea-->>Dev: 4️⃣ Tunneled Connection
    deactivate MySQL
    deactivate Gitea
    Note over Dev,MySQL: ✅ Developer connected to MySQL<br/>via encrypted SSH tunnel

🔐 Network Security Groups (NSG):

graph LR
subgraph NSG_Gitea["🛡️ Gitea VM NSG (Public)"]
In1["📥 Inbound Rules<br/>━━━━━━━━━<br/>✅ SSH :22 from 0.0.0.0/0<br/>✅ Gitea :3000 from LB<br/>✅ HTTP :80 from LB"]
Out1["📤 Outbound Rules<br/>━━━━━━━━━<br/>✅ All traffic allowed"]
end

    subgraph NSG_MySQL["🛡️ MySQL VM NSG (Private)"]
        In2["📥 Inbound Rules<br/>━━━━━━━━━<br/>✅ SSH :22 from 10.1.2.0/24<br/>✅ MySQL :3306 from 10.1.2.0/24<br/>❌ DENY all from Internet"]
        Out2["📤 Outbound Rules<br/>━━━━━━━━━<br/>✅ Limited to VNet only"]
    end

    Internet["🌐 Internet"] -->|Allowed| In1
    In1 --> Out1
    Out1 -.->|SSH Tunnel| In2
    In2 --> Out2
    Internet -.->|❌ BLOCKED| In2

    style NSG_Gitea fill:#c8e6c9,stroke:#2e7d32,stroke-width:3px
    style NSG_MySQL fill:#ffcdd2,stroke:#c62828,stroke-width:3px
    style Internet fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    style In1 fill:#fff9c4,stroke:#f57f17,stroke-width:1px
    style In2 fill:#fff9c4,stroke:#f57f17,stroke-width:1px
    style Out1 fill:#f3e5f5,stroke:#4a148c,stroke-width:1px
    style Out2 fill:#f3e5f5,stroke:#4a148c,stroke-width:1px

Graph TB - Topología del Túnel VPN con Binlog Streaming

graph TB
subgraph AWS["AWS RDS MySQL PRIMARY"]
RDS["🗄️ RDS MySQL 8.0<br/>IP: 10.0.2.50:3306<br/>server-id: 1"]
Binlog["📝 Binlog Stream<br/>mysql-bin.000005<br/>Format: ROW"]
RDS -->|"Generate Events"| Binlog
end

    subgraph VPNTunnel["🔒 IPsec VPN TUNNEL"]
        AWSGW["AWS VPN Gateway<br/>ASN: 64512<br/>Public IP: AWS_VPN"]
        Encrypt["🔐 Encryption Layer<br/>━━━━━━━━━━━━━━━<br/>Protocol: IKEv2<br/>Cipher: AES-256-CBC<br/>Auth: SHA-256 HMAC<br/>DH Group: 14<br/>PSK: SHARED_SECRET<br/>━━━━━━━━━━━━━━━"]
        AzureGW["Azure VPN Gateway<br/>ASN: 65515<br/>Public IP: AZURE_VPN"]

        AWSGW --> Encrypt
        Encrypt --> AzureGW
    end

    subgraph Azure["Azure MySQL VM REPLICA"]
        IOThread["⚙️ Slave IO Thread<br/>Connects to 10.0.2.50"]
        RelayLog["📋 Relay Log<br/>relay-bin.000003<br/>Position: 8901"]
        SQLThread["⚙️ Slave SQL Thread<br/>Applies Transactions"]
        AzMySQL["🗄️ MySQL 8.0 VM<br/>IP: 10.1.2.50:3306<br/>server-id: 2"]

        IOThread -->|"Write"| RelayLog
        RelayLog -->|"Read"| SQLThread
        SQLThread -->|"Execute"| AzMySQL
    end

    Binlog -->|"Stream via 10.0.0.0/16"| AWSGW
    AzureGW -->|"Decrypt via 10.1.0.0/16"| IOThread

    AzMySQL -.->|"ACK Received"| IOThread
    IOThread -.->|"Request More Events"| AWSGW

    style RDS fill:#ff9900,stroke:#232f3e,stroke-width:3px,color:#fff
    style Binlog fill:#ffd700,stroke:#000,stroke-width:2px
    style AWSGW fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style Encrypt fill:#dc143c,stroke:#fff,stroke-width:4px,color:#fff
    style AzureGW fill:#0078d4,stroke:#fff,stroke-width:2px,color:#fff
    style IOThread fill:#87ceeb,stroke:#000,stroke-width:2px
    style RelayLog fill:#90ee90,stroke:#000,stroke-width:2px
    style SQLThread fill:#87ceeb,stroke:#000,stroke-width:2px
    style AzMySQL fill:#0078d4,stroke:#fff,stroke-width:3px,color:#fff

Graph LR - Configuración Completa de Replicación y VPN -> no se si usarlo

graph LR
subgraph Primary["🗄️ AWS RDS PRIMARY Config"]
P1["server-id = 1"]
P2["log_bin = mysql-bin"]
P3["binlog_format = ROW"]
P4["binlog_retention = 168h"]
P5["backup_retention = 7d"]
P6["database = giteadb"]

        P1 --> P2 --> P3 --> P4 --> P5 --> P6
    end

    subgraph RepUser["👤 Replication User"]
        U1["CREATE USER<br/>replica_user@10.1.2.50"]
        U2["GRANT<br/>REPLICATION SLAVE"]
        U3["GRANT<br/>REPLICATION CLIENT"]
        U4["GRANT SELECT<br/>ON giteadb.*"]

        U1 --> U2 --> U3 --> U4
    end

    subgraph VPN["🔐 IPsec VPN Tunnel"]
        V1["IKEv2 Protocol"]
        V2["Phase 1:<br/>Main Mode<br/>DH Group 14"]
        V3["Phase 2:<br/>Quick Mode<br/>AES-256-CBC"]
        V4["Routes:<br/>10.0.0.0/16 ↔<br/>10.1.0.0/16"]
        V5["PSK Auth:<br/>SHARED_SECRET"]
        V6["Dead Peer<br/>Detection: 10s"]

        V1 --> V2 --> V3
        V2 --> V5
        V3 --> V4 --> V6
    end

    subgraph Replica["🗄️ Azure MySQL REPLICA Config"]
        R1["server-id = 2"]
        R2["relay-log = relay-bin"]
        R3["read_only = ON"]
        R4["log_slave_updates = ON"]
        R5["master_info_repository<br/>= TABLE"]
        R6["relay_log_info_repository<br/>= TABLE"]

        R1 --> R2 --> R3 --> R4 --> R5 --> R6
    end

    subgraph ChangeMaster["⚙️ CHANGE MASTER Command"]
        C1["MASTER_HOST =<br/>10.0.2.50"]
        C2["MASTER_PORT =<br/>3306"]
        C3["MASTER_USER =<br/>replica_user"]
        C4["MASTER_PASSWORD =<br/>***"]
        C5["MASTER_LOG_FILE =<br/>mysql-bin.000001"]
        C6["MASTER_LOG_POS =<br/>157"]

        C1 --> C2 --> C3 --> C4 --> C5 --> C6
    end

    subgraph Status["📊 Replication Status"]
        S1["Slave_IO_Running:<br/>Yes"]
        S2["Slave_SQL_Running:<br/>Yes"]
        S3["Seconds_Behind_Master:<br/>0"]
        S4["Last_Error:<br/>none"]

        S1 --> S2 --> S3 --> S4
    end

    Primary --> RepUser
    RepUser --> VPN
    VPN --> ChangeMaster
    Replica --> ChangeMaster
    ChangeMaster --> Status

    style Primary fill:#ff9900,stroke:#232f3e,stroke-width:3px,color:#fff
    style RepUser fill:#32cd32,stroke:#000,stroke-width:2px
    style VPN fill:#dc143c,stroke:#fff,stroke-width:3px,color:#fff
    style Replica fill:#0078d4,stroke:#fff,stroke-width:3px,color:#fff
    style ChangeMaster fill:#ffa500,stroke:#000,stroke-width:2px
    style Status fill:#00ff00,stroke:#000,stroke-width:3px

Diagrama VPN Site-to-Site (IPsec Tunnel)

graph TB
subgraph AWS["☁️ AWS Cloud - us-east-1<br/>VPC: 10.0.0.0/16"]
AWSSubnet["Private Subnet<br/>10.0.2.0/24"]
AWSVPN["🔐 AWS Virtual Private Gateway<br/>━━━━━━━━━━━━━━━━━━━━<br/>Type: VGW<br/>ASN: 64512<br/>Public IP: AWS_VPN_PUBLIC_IP<br/>Attachment: VPC-attached"]
AWSRoute["📋 Route Table<br/>Destination: 10.1.0.0/16<br/>Target: vgw-xxxxx"]

        AWSSubnet --> AWSVPN
        AWSRoute -.-> AWSVPN
    end

    subgraph Tunnel["🔒 IPsec VPN TUNNEL"]
        IKE["━━━━━━━━━━━━━━━━━━━━━━━━<br/>IKE Phase 1 (ISAKMP SA)<br/>━━━━━━━━━━━━━━━━━━━━━━━━<br/>Protocol: IKEv2<br/>Mode: Main Mode<br/>Encryption: AES-256-CBC<br/>Integrity: SHA-256 HMAC<br/>DH Group: 14 (2048-bit MODP)<br/>Authentication: PSK<br/>Pre-Shared Key: SHARED_SECRET<br/>Lifetime: 28800s (8h)<br/>━━━━━━━━━━━━━━━━━━━━━━━━"]

        IPsec["━━━━━━━━━━━━━━━━━━━━━━━━<br/>IKE Phase 2 (IPsec SA)<br/>━━━━━━━━━━━━━━━━━━━━━━━━<br/>Protocol: ESP (Encap Security)<br/>Mode: Tunnel Mode<br/>Encryption: AES-256-CBC<br/>Integrity: SHA-256 HMAC<br/>PFS: Enabled (Group 14)<br/>Lifetime: 3600s (1h)<br/>DPD: Enabled (10s interval)<br/>━━━━━━━━━━━━━━━━━━━━━━━━"]

        Traffic["📦 Encrypted Traffic<br/>━━━━━━━━━━━━━━━━<br/>MTU: 1400 bytes<br/>Protocol: ESP<br/>SPI: Security Parameter Index<br/>Sequence Number: Anti-replay<br/>━━━━━━━━━━━━━━━━"]

        IKE --> IPsec --> Traffic
    end

    subgraph Azure["☁️ Azure Cloud - East US<br/>VNet: 10.1.0.0/16"]
        AzureRoute["📋 Route Table<br/>Address Prefix: 10.0.0.0/16<br/>Next Hop: VPN Gateway"]
        AzureVPN["🔐 Azure VPN Gateway<br/>━━━━━━━━━━━━━━━━━━━━<br/>SKU: VpnGw1<br/>Type: Route-based<br/>ASN: 65515<br/>Public IP: AZURE_VPN_PUBLIC_IP<br/>Active-Active: No"]
        AzureSubnet["Private Subnet<br/>10.1.2.0/24"]

        AzureVPN --> AzureSubnet
        AzureVPN -.-> AzureRoute
    end

    AWSVPN -->|"1️⃣ IKE_SA_INIT<br/>Negotiate crypto"| IKE
    IKE -->|"2️⃣ IKE_AUTH<br/>PSK verification"| AzureVPN

    AWSVPN -->|"3️⃣ CREATE_CHILD_SA<br/>Establish IPsec"| IPsec
    IPsec -->|"4️⃣ IPsec SA Ready<br/>Tunnel UP"| AzureVPN

    AWSSubnet -->|"5️⃣ Data Packets<br/>10.0.2.50 → 10.1.2.50"| Traffic
    Traffic -->|"6️⃣ Decrypted<br/>10.0.2.50 → 10.1.2.50"| AzureSubnet

    AzureSubnet -.->|"7️⃣ Return Traffic<br/>10.1.2.50 → 10.0.2.50"| Traffic
    Traffic -.->|"8️⃣ Decrypted<br/>10.1.2.50 → 10.0.2.50"| AWSSubnet

    style AWSVPN fill:#ff9900,stroke:#232f3e,stroke-width:3px,color:#fff
    style IKE fill:#dc143c,stroke:#fff,stroke-width:3px,color:#fff
    style IPsec fill:#8b0000,stroke:#fff,stroke-width:3px,color:#fff
    style Traffic fill:#4b0082,stroke:#fff,stroke-width:3px,color:#fff
    style AzureVPN fill:#0078d4,stroke:#fff,stroke-width:3px,color:#fff
    style AWSRoute fill:#ffd700,stroke:#000,stroke-width:2px
    style AzureRoute fill:#ffd700,stroke:#000,stroke-width:2px
    style AWSSubnet fill:#ffe4b5,stroke:#000,stroke-width:2px
    style AzureSubnet fill:#ffe4b5,stroke:#000,stroke-width:2px

Configuración Detallada del Túnel

    graph LR
    subgraph Config["🔧 VPN Tunnel Configuration"]
        direction TB

        subgraph Phase1["IKE Phase 1 (ISAKMP)"]
            P1_1["Version: IKEv2"]
            P1_2["Mode: Main Mode"]
            P1_3["Encryption: AES-256-CBC"]
            P1_4["Integrity: SHA-256"]
            P1_5["DH Group: 14"]
            P1_6["Auth Method: PSK"]
            P1_7["Lifetime: 28800s"]

            P1_1 --> P1_2 --> P1_3 --> P1_4 --> P1_5 --> P1_6 --> P1_7
        end

        subgraph Phase2["IKE Phase 2 (IPsec)"]
            P2_1["Protocol: ESP"]
            P2_2["Mode: Tunnel"]
            P2_3["Encryption: AES-256-CBC"]
            P2_4["Integrity: SHA-256"]
            P2_5["PFS: Enabled (Group 14)"]
            P2_6["Lifetime: 3600s"]
            P2_7["DPD Interval: 10s"]

            P2_1 --> P2_2 --> P2_3 --> P2_4 --> P2_5 --> P2_6 --> P2_7
        end

        subgraph Routing["Network Routing"]
            R1["AWS VPC: 10.0.0.0/16"]
            R2["Azure VNet: 10.1.0.0/16"]
            R3["Route: 10.1.0.0/16 → VGW"]
            R4["Route: 10.0.0.0/16 → VPN GW"]

            R1 --> R3
            R2 --> R4
        end

        subgraph Security["Security Parameters"]
            S1["Pre-Shared Key:<br/>32-char secret"]
            S2["Anti-Replay:<br/>Sequence numbers"]
            S3["Perfect Forward Secrecy:<br/>New DH exchange"]
            S4["Dead Peer Detection:<br/>10s timeout"]

            S1 --> S2 --> S3 --> S4
        end
    end

    Phase1 --> Phase2
    Phase2 --> Routing
    Routing --> Security
    Security --> Result["✅ Secure Tunnel<br/>Status: UP<br/>Encryption: Active<br/>Traffic: Bidirectional"]

    style Phase1 fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style Phase2 fill:#8b0000,stroke:#fff,stroke-width:2px,color:#fff
    style Routing fill:#ffa500,stroke:#000,stroke-width:2px
    style Security fill:#dc143c,stroke:#fff,stroke-width:2px,color:#fff
    style Result fill:#00ff00,stroke:#000,stroke-width:3px

Diagrama de Arquitectura - Sistema de Monitoreo y Disaster Recovery

    graph TB
    subgraph Azure["☁️ AZURE CLOUD - Monitoring Infrastructure"]
        Timer["⏰ Timer Trigger<br/>━━━━━━━━━━━━━<br/>Schedule: */5 minutes<br/>CRON: 0 */5 * * * *<br/>Run on Startup: False"]

        AzFunc["⚡ Azure Function<br/>disaster_recovery_monitor()<br/>━━━━━━━━━━━━━━━━━━━<br/>Runtime: Python 3.9+<br/>Timeout: 5 minutes<br/>Extension Bundle: 3.x<br/>App Insights: Enabled"]

        HealthCheck["🔍 Health Check Module<br/>perform_health_check()<br/>━━━━━━━━━━━━━━━━━━━<br/>Max Retries: 3<br/>Timeout: 30s per attempt<br/>User-Agent: Enterprise-DR-Monitor/1.0"]

        Logger["📊 Application Insights<br/>━━━━━━━━━━━━━━━━<br/>Correlation ID tracking<br/>Sampling: Enabled<br/>Log Level: INFO/WARNING/ERROR"]

        AlertEngine["🚨 Alert Engine<br/>send_enterprise_alert()<br/>━━━━━━━━━━━━━━━━━━━<br/>SMTP: smtp.office365.com:587<br/>TLS: Enabled<br/>Random recipient selection: 4"]

        EmailSvc["📧 Email Service<br/>create_professional_email()<br/>━━━━━━━━━━━━━━━━━━━<br/>Format: HTML + Plain Text<br/>Priority: High (X-Priority: 1)<br/>Template: Professional DR"]

        Timer -->|"Every 5 min"| AzFunc
        AzFunc -->|"1️⃣ Execute"| HealthCheck
        AzFunc -->|"Log events"| Logger
        HealthCheck -->|"2️⃣ If FAILED"| AlertEngine
        AlertEngine -->|"3️⃣ Generate & Send"| EmailSvc
    end

    subgraph AWS["☁️ AWS CLOUD - Monitored Infrastructure"]
        AWSALB["⚖️ Application Load Balancer<br/>Public Endpoint"]
        AWSGitea["🖥️ EC2 Instance<br/>Gitea Application<br/>Private IP: 10.0.x.x"]

        AWSALB -->|"Route traffic"| AWSGitea
    end

    subgraph Internet["🌐 PUBLIC INTERNET"]
        Endpoint["🎯 Monitored Endpoint<br/>━━━━━━━━━━━━━━━━━━━<br/>URL: http://20.185.185.20:3000<br/>/explore/repos<br/>Protocol: HTTP<br/>Expected: 200 OK"]
    end

    subgraph Recipients["👥 OPERATIONS TEAM"]
        Tech1["👨‍💻 SRE Lead<br/>sre.lead@company.com"]
        Tech2["👨‍💻 DevOps Manager<br/>devops.manager@company.com"]
        Tech3["👨‍💻 Infrastructure Engineer<br/>infrastructure.engineer@company.com"]
        Tech4["👨‍💻 Platform Architect<br/>platform.architect@company.com"]
    end

    HealthCheck -->|"HTTP GET Request<br/>with Correlation-ID"| Endpoint
    Endpoint -->|"Proxy to"| AWSALB

    EmailSvc -.->|"4️⃣ Disaster Recovery Alert"| Tech1
    EmailSvc -.->|"4️⃣ Disaster Recovery Alert"| Tech2
    EmailSvc -.->|"4️⃣ Disaster Recovery Alert"| Tech3
    EmailSvc -.->|"4️⃣ Disaster Recovery Alert"| Tech4

    style Timer fill:#0078d4,stroke:#fff,stroke-width:2px,color:#fff
    style AzFunc fill:#0078d4,stroke:#fff,stroke-width:3px,color:#fff
    style HealthCheck fill:#00a4ef,stroke:#fff,stroke-width:2px,color:#fff
    style Logger fill:#50e6ff,stroke:#000,stroke-width:2px
    style AlertEngine fill:#dc3545,stroke:#fff,stroke-width:3px,color:#fff
    style EmailSvc fill:#ffc107,stroke:#000,stroke-width:2px
    style Endpoint fill:#ff9900,stroke:#232f3e,stroke-width:3px,color:#fff
    style AWSALB fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style AWSGitea fill:#ec7211,stroke:#232f3e,stroke-width:2px,color:#fff
    style Tech1 fill:#28a745,stroke:#fff,stroke-width:2px,color:#fff
    style Tech2 fill:#28a745,stroke:#fff,stroke-width:2px,color:#fff
    style Tech3 fill:#28a745,stroke:#fff,stroke-width:2px,color:#fff
    style Tech4 fill:#28a745,stroke:#fff,stroke-width:2px,color:#fff

Configuración Técnica Detallada - pero no lo creo necesario, con el anterior es suficiente

    graph LR
    subgraph FunctionConfig["⚙️ Azure Function Configuration"]
        Runtime["Python Runtime<br/>━━━━━━━━━━━━<br/>Version: 3.9+<br/>Package: azure-functions"]
        Trigger["Timer Trigger<br/>━━━━━━━━━━━━<br/>CRON: 0 */5 * * * *<br/>Frequency: Every 5 min<br/>Startup: False"]
        Timeout["Execution Timeout<br/>━━━━━━━━━━━━<br/>Max Duration: 5 minutes<br/>Bundle: v3.x"]

        Runtime --> Trigger --> Timeout
    end

    subgraph HealthConfig["🔍 Health Check Configuration"]
        Endpoint["Target Endpoint<br/>━━━━━━━━━━━━<br/>URL: http://20.185.185.20:3000<br/>/explore/repos<br/>⚠️ Hardcoded (Security Issue)"]
        Retry["Retry Logic<br/>━━━━━━━━━━━━<br/>Max Attempts: 3<br/>Timeout per attempt: 30s<br/>Total max time: 90s"]
        Headers["HTTP Headers<br/>━━━━━━━━━━━━<br/>User-Agent: Enterprise-DR-Monitor<br/>X-Correlation-ID: DR-{timestamp}"]

        Endpoint --> Retry --> Headers
    end

    subgraph AlertConfig["🚨 Alert Configuration"]
        Severity["Severity Levels<br/>━━━━━━━━━━━━<br/>CRITICAL: All retries failed<br/>HIGH: HTTP 5xx errors<br/>MEDIUM: Other failures"]
        Recipients["Recipient List<br/>━━━━━━━━━━━━<br/>Total: 4 technicians<br/>Selection: Random 4<br/>Distribution: Load balanced"]

        Severity --> Recipients
    end

    subgraph EmailConfig["📧 Email Service Configuration"]
        SMTP["SMTP Server<br/>━━━━━━━━━━━━<br/>Host: smtp.office365.com<br/>Port: 587<br/>TLS: Required"]
        Auth["Authentication<br/>━━━━━━━━━━━━<br/>User: EMAIL_USER (env var)<br/>Pass: EMAIL_PASSWORD (env var)<br/>Method: STARTTLS"]
        Format["Message Format<br/>━━━━━━━━━━━━<br/>MIME: Multipart/alternative<br/>Plain Text: Yes<br/>HTML: Professional template<br/>Priority: High (X-Priority: 1)"]

        SMTP --> Auth --> Format
    end

    subgraph LogConfig["📊 Logging Configuration"]
        AppInsights["Application Insights<br/>━━━━━━━━━━━━<br/>Sampling: Enabled<br/>Excluded: Request type<br/>Correlation: ID tracking"]
        LogLevels["Log Levels<br/>━━━━━━━━━━━━<br/>INFO: Health checks OK<br/>WARNING: Service down<br/>ERROR: Alert dispatch failed"]

        AppInsights --> LogLevels
    end

    subgraph EnvVars["🔐 Environment Variables"]
        E1["SMTP_SERVER<br/>Default: smtp.office365.com"]
        E2["SMTP_PORT<br/>Default: 587"]
        E3["EMAIL_USER<br/>Required: Sender email"]
        E4["EMAIL_PASSWORD<br/>Required: SMTP password"]
        E5["COMPANY_NAME<br/>Default: Enterprise Solutions Inc."]

        E1 --> E2 --> E3 --> E4 --> E5
    end

    FunctionConfig --> HealthConfig
    HealthConfig --> AlertConfig
    AlertConfig --> EmailConfig
    EmailConfig --> LogConfig
    LogConfig --> EnvVars
    EnvVars --> Result["✅ Monitoring System Active<br/>━━━━━━━━━━━━━━━━━━<br/>Status: Running<br/>Frequency: Every 5 minutes<br/>Alert Capability: Email<br/>Monitoring Target: AWS Gitea"]

    style FunctionConfig fill:#0078d4,stroke:#fff,stroke-width:2px,color:#fff
    style HealthConfig fill:#00a4ef,stroke:#fff,stroke-width:2px,color:#fff
    style AlertConfig fill:#dc3545,stroke:#fff,stroke-width:2px,color:#fff
    style EmailConfig fill:#ffc107,stroke:#000,stroke-width:2px
    style LogConfig fill:#50e6ff,stroke:#000,stroke-width:2px
    style EnvVars fill:#28a745,stroke:#fff,stroke-width:2px,color:#fff
    style Endpoint fill:#ff0000,stroke:#fff,stroke-width:3px,color:#fff
    style Result fill:#00ff00,stroke:#000,stroke-width:3px

Diagrama de los 3 Modos de Deployment

    graph TB
    subgraph Jenkins["🔧 JENKINS PIPELINE PARAMETERS"]
        Params["📋 Pipeline Parameters<br/>━━━━━━━━━━━━━━━━━━━<br/>PLAN_TERRAFORM: bool<br/>APPLY_TERRAFORM: bool<br/>DEPLOY_ANSIBLE: bool<br/>DESTROY_TERRAFORM: bool<br/>DEPLOYMENT_MODE: choice"]

        Choice{"🎯 DEPLOYMENT_MODE<br/>Selection"}
    end

    Params --> Choice

    Choice -->|"full-stack"| FullStack["📦 MODE 1: FULL-STACK<br/>━━━━━━━━━━━━━━━━━━━<br/>Complete Demo Infrastructure"]
    Choice -->|"replica-only"| ReplicaOnly["🔄 MODE 2: REPLICA-ONLY<br/>━━━━━━━━━━━━━━━━━━━<br/>MySQL as AWS Replica"]
    Choice -->|"failover"| Failover["⚡ MODE 3: FAILOVER<br/>━━━━━━━━━━━━━━━━━━━<br/>Emergency Recovery"]

    subgraph Mode1["MODE 1: FULL-STACK DEPLOYMENT"]
        direction TB
        F1["🏗️ Terraform Deploy"]
        F2["├─ Resource Group<br/>├─ VNet + Subnets<br/>├─ NSGs<br/>├─ Gitea VM (public IP)<br/>├─ MySQL VM (private IP)<br/>└─ Azure Load Balancer"]
        F3["📝 Ansible Inventory"]
        F4["[azureGitea]<br/>gitea-vm: ${VM_PUBLIC_IP}<br/><br/>[mysql]<br/>mysql-vm: ${MYSQL_PRIVATE_IP}<br/>ProxyJump via gitea-vm"]
        F5["🎭 Ansible Playbook"]
        F6["├─ Install Gitea on VM<br/>├─ Install MySQL on VM<br/>├─ Configure app.ini<br/>├─ Create giteadb<br/>└─ Start services"]
        F7["✅ Result"]
        F8["Working Demo:<br/>Gitea + MySQL + LB<br/>MySQL: Temporary public IP<br/>Access: SSH ProxyJump"]

        F1 --> F2 --> F3 --> F4 --> F5 --> F6 --> F7 --> F8
    end

    subgraph Mode2["MODE 2: REPLICA-ONLY DEPLOYMENT"]
        direction TB
        R1["🏗️ Terraform Deploy"]
        R2["├─ Resource Group<br/>├─ VNet (10.1.0.0/16)<br/>├─ MySQL VM (private only)<br/>├─ VPN Gateway<br/>├─ DESTROY: Gitea VM<br/>└─ DESTROY: Load Balancer"]
        R3["📝 Ansible Inventory"]
        R4["[mysql]<br/>mysql-vm: ${MYSQL_PRIVATE_IP}<br/>Access: Via VPN only<br/>⚠️ No public IP"]
        R5["🎭 Ansible Playbook"]
        R6["├─ Install MySQL 8.0<br/>├─ Configure as REPLICA<br/>├─ server-id = 2<br/>├─ read_only = ON<br/>├─ relay-log = relay-bin<br/>└─ CHANGE MASTER TO<br/>    MASTER_HOST=10.0.2.50"]
        R7["✅ Result"]
        R8["MySQL Replica Active:<br/>Syncs from AWS RDS<br/>Via Site-to-Site VPN<br/>⚠️ Requires AWS VPN IP"]

        R1 --> R2 --> R3 --> R4 --> R5 --> R6 --> R7 --> R8
    end

    subgraph Mode3["MODE 3: FAILOVER DEPLOYMENT"]
        direction TB
        FL1["🏗️ Terraform Deploy"]
        FL2["├─ Gitea VM (public IP)<br/>├─ Azure Load Balancer<br/>├─ NSG rules<br/>└─ SKIP: MySQL VM<br/>    (assumes exists)"]
        FL3["📝 Ansible Inventory"]
        FL4["[azureGitea]<br/>gitea-vm: ${VM_PUBLIC_IP}<br/><br/>[all:vars]<br/>mysql_host=${MYSQL_PRIVATE_IP}<br/>Uses existing MySQL"]
        FL5["🎭 Ansible Playbook"]
        FL6["├─ Install Gitea on VM<br/>├─ Configure to use<br/>   existing MySQL<br/>├─ Point to 10.1.2.50<br/>└─ Start Gitea service"]
        FL7["🚨 Manual Steps"]
        FL8["DBA must:<br/>1. STOP SLAVE;<br/>2. RESET SLAVE ALL;<br/>3. Promote to PRIMARY<br/>4. Verify data current"]
        FL9["✅ Result"]
        FL10["Disaster Recovery:<br/>Gitea restored<br/>Using replicated MySQL<br/>Update DNS → Azure"]

        FL1 --> FL2 --> FL3 --> FL4 --> FL5 --> FL6 --> FL7 --> FL8 --> FL9 --> FL10
    end

    FullStack --> Mode1
    ReplicaOnly --> Mode2
    Failover --> Mode3

    style Choice fill:#ffa500,stroke:#000,stroke-width:3px
    style FullStack fill:#28a745,stroke:#fff,stroke-width:3px,color:#fff
    style ReplicaOnly fill:#0078d4,stroke:#fff,stroke-width:3px,color:#fff
    style Failover fill:#dc3545,stroke:#fff,stroke-width:3px,color:#fff
    style F1 fill:#28a745,stroke:#fff,stroke-width:2px,color:#fff
    style R1 fill:#0078d4,stroke:#fff,stroke-width:2px,color:#fff
    style FL1 fill:#dc3545,stroke:#fff,stroke-width:2px,color:#fff
    style F8 fill:#00ff00,stroke:#000,stroke-width:2px
    style R8 fill:#87ceeb,stroke:#000,stroke-width:2px
    style FL10 fill:#ff6b6b,stroke:#000,stroke-width:2px

Comparación Técnica de los 3 Modos

    graph LR
    subgraph Comparison["📊 TECHNICAL COMPARISON TABLE"]
        direction TB

        subgraph Components["🏗️ Infrastructure Components"]
            C1["Component"]
            C2["full-stack"]
            C3["replica-only"]
            C4["failover"]

            C1 --> C2
            C1 --> C3
            C1 --> C4
        end

        subgraph Gitea["🖥️ Gitea VM"]
            G1["Deployed?"]
            G2["✅ YES<br/>Public IP"]
            G3["❌ NO<br/>Destroyed"]
            G4["✅ YES<br/>Public IP"]

            G1 --> G2
            G1 --> G3
            G1 --> G4
        end

        subgraph MySQL["🗄️ MySQL VM"]
            M1["Deployed?"]
            M2["✅ YES<br/>Private IP<br/>Temp Public"]
            M3["✅ YES<br/>Private only<br/>Replica Config"]
            M4["⚠️ EXISTING<br/>Already deployed<br/>From Mode 2"]

            M1 --> M2
            M1 --> M3
            M1 --> M4
        end

        subgraph LB["⚖️ Load Balancer"]
            L1["Deployed?"]
            L2["✅ YES<br/>Public IP<br/>Port 80→3000"]
            L3["❌ NO<br/>Destroyed"]
            L4["✅ YES<br/>Public IP<br/>Port 80→3000"]

            L1 --> L2
            L1 --> L3
            L1 --> L4
        end

        subgraph VPN["🔐 VPN Gateway"]
            V1["Deployed?"]
            V2["❌ NO<br/>Not needed"]
            V3["✅ YES<br/>Site-to-Site<br/>to AWS"]
            V4["⚠️ OPTIONAL<br/>Keep if exists"]

            V1 --> V2
            V1 --> V3
            V1 --> V4
        end

        subgraph Access["🔑 MySQL Access Method"]
            A1["Access"]
            A2["SSH ProxyJump<br/>via Gitea VM<br/>Port 3306"]
            A3["VPN Tunnel<br/>10.1.0.0/16<br/>Private only"]
            A4["SSH ProxyJump<br/>via Gitea VM<br/>Private IP"]

            A1 --> A2
            A1 --> A3
            A1 --> A4
        end

        subgraph Purpose["🎯 Use Case"]
            P1["Purpose"]
            P2["Complete Demo<br/>Standalone<br/>No replication"]
            P3["AWS Replica<br/>Binlog sync<br/>Hot standby"]
            P4["Emergency DR<br/>Promote replica<br/>Full recovery"]

            P1 --> P2
            P1 --> P3
            P1 --> P4
        end

        subgraph Ansible["🎭 Ansible Tasks"]
            AN1["Tasks"]
            AN2["Install both:<br/>Gitea + MySQL<br/>Fresh setup"]
            AN3["MySQL only:<br/>Replica config<br/>CHANGE MASTER"]
            AN4["Gitea only:<br/>Connect to<br/>existing MySQL"]

            AN1 --> AN2
            AN1 --> AN3
            AN1 --> AN4
        end
    end

    style C2 fill:#28a745,stroke:#fff,stroke-width:2px,color:#fff
    style C3 fill:#0078d4,stroke:#fff,stroke-width:2px,color:#fff
    style C4 fill:#dc3545,stroke:#fff,stroke-width:2px,color:#fff
    style G2 fill:#00ff00,stroke:#000,stroke-width:2px
    style G3 fill:#ff0000,stroke:#fff,stroke-width:2px,color:#fff
    style G4 fill:#00ff00,stroke:#000,stroke-width:2px
    style M2 fill:#00ff00,stroke:#000,stroke-width:2px
    style M3 fill:#87ceeb,stroke:#000,stroke-width:2px
    style M4 fill:#ffa500,stroke:#000,stroke-width:2px
    style L2 fill:#00ff00,stroke:#000,stroke-width:2px
    style L3 fill:#ff0000,stroke:#fff,stroke-width:2px,color:#fff
    style L4 fill:#00ff00,stroke:#000,stroke-width:2px
    style V2 fill:#ff0000,stroke:#fff,stroke-width:2px,color:#fff
    style V3 fill:#00ff00,stroke:#000,stroke-width:2px
    style V4 fill:#ffa500,stroke:#000,stroke-width:2px
