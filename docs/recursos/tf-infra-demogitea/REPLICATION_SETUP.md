# Gitea Failover Setup: AWS to Azure Replication

This guide explains how to configure MySQL replication from AWS RDS (master) to Azure MySQL Flexible Server (replica) for Gitea failover capability.

## Architecture Overview

```
AWS (us-east-1)                      Azure (East US)
┌─────────────────┐                  ┌─────────────────┐
│ VPC 10.0.0.0/16 │                  │ VNet 10.1.0.0/16│
│                 │                  │                 │
│ ┌─────────────┐ │   VPN Site-to-  │ ┌─────────────┐ │
│ │ RDS MySQL   │◄├─────Site────────┤►│ MySQL Flex  │ │
│ │ (Master)    │ │   IPsec Tunnel  │ │ (Replica)   │ │
│ └─────────────┘ │                  │ └─────────────┘ │
│                 │                  │                 │
│ ┌─────────────┐ │                  │ ┌─────────────┐ │
│ │ EC2 Gitea   │ │                  │ │ VM Gitea    │ │
│ └─────────────┘ │                  │ └─────────────┘ │
└─────────────────┘                  └─────────────────┘
```

## Prerequisites

- Both AWS and Azure Terraform repositories cloned
- AWS and Azure CLI configured with proper credentials
- Access to both AWS and Azure consoles

## Step-by-Step Setup

### Phase 1: Deploy Azure Infrastructure (Standalone)

1. **Deploy Azure infrastructure first** to get the VPN Gateway public IP:
   ```bash
   cd TF-AZ-INFRA-DEMOGITEA/infra
   terraform init
   terraform plan
   terraform apply
   ```

2. **Note the outputs**:
   ```bash
   terraform output vpn_gateway_public_ip
   # Example: 20.123.45.67
   ```

3. **Save these values** for AWS configuration:
   - `vpn_gateway_public_ip` - Needed for AWS Customer Gateway
   - `mysql_server_host` - For replication setup
   - `mysql_admin_password` - For Azure MySQL access

### Phase 2: Enable VPN and Binlog in AWS

4. **Update AWS terraform.tfvars** with Azure VPN IP:
   ```bash
   cd TF-INFRA-DEMOGITEA/infra
   cp terraform.tfvars.example terraform.tfvars
   ```

5. **Edit `terraform.tfvars`** and uncomment:
   ```hcl
   enable_vpn_gateway    = true
   azure_vpn_gateway_ip  = "20.123.45.67"  # From Azure output
   azure_vnet_cidr       = "10.1.0.0/16"
   vpn_shared_key        = "YourSecureSharedKey123!"

   enable_binlog         = true
   replication_user      = "repl_azure"
   replication_password  = "SecurePassword123!"
   ```

6. **Deploy AWS changes**:
   ```bash
   terraform plan  # Review changes: RDS backup retention 0→7, VPN Gateway added
   terraform apply
   ```

7. **Note AWS VPN tunnel IPs**:
   ```bash
   terraform output vpn_tunnel1_address
   # Example: 52.123.45.67
   terraform output vpn_tunnel2_address
   # Example: 52.123.45.68
   ```

### Phase 3: Update Azure with AWS VPN IPs

8. **Update Azure terraform.tfvars**:
   ```bash
   cd TF-AZ-INFRA-DEMOGITEA/infra
   ```

9. **Edit `terraform.tfvars`** to enable VPN:
   ```hcl
   enable_vpn_gateway = true
   aws_vpn_tunnel1_ip = "52.123.45.67"  # From AWS output
   vpn_shared_key     = "YourSecureSharedKey123!"  # Must match AWS
   aws_vpc_cidr       = "10.0.0.0/16"
   ```

10. **Redeploy Azure infrastructure**:
    ```bash
    terraform apply
    ```

### Phase 4: Create MySQL Replication User on AWS

11. **Connect to AWS RDS**:
    ```bash
    mysql -h your-rds-endpoint.us-east-1.rds.amazonaws.com -u dbuser -p
    ```

12. **Create replication user**:
    ```sql
    CREATE USER 'repl_azure'@'%' IDENTIFIED BY 'SecurePassword123!';
    GRANT REPLICATION SLAVE ON *.* TO 'repl_azure'@'%';
    FLUSH PRIVILEGES;
    SHOW MASTER STATUS;
    ```

13. **Note the binlog position**:
    ```
    +------------------+----------+
    | File             | Position |
    +------------------+----------+
    | mysql-bin.000001 |     1234 |
    +------------------+----------+
    ```

### Phase 5: Configure Replication on Azure

14. **Update Azure terraform.tfvars** with replication details:
    ```hcl
    enable_replication          = true
    aws_rds_endpoint            = "your-rds-endpoint.us-east-1.rds.amazonaws.com"
    replication_user            = "repl_azure"
    replication_password        = "SecurePassword123!"
    master_log_file             = "mysql-bin.000001"
    master_log_position         = 1234
    ```

15. **Apply Azure replication configuration**:
    ```bash
    cd TF-AZ-INFRA-DEMOGITEA/infra
    terraform apply
    ```

### Phase 6: Verify Replication

16. **Check VPN connection status**:
    ```bash
    # AWS Console: VPC → VPN Connections → Check status (both tunnels should be "UP")
    # Azure Portal: Virtual Network Gateway → Connections → Check status
    ```

17. **Test connectivity from Azure to AWS RDS**:
    ```bash
    # SSH to Azure VM
    mysql -h your-rds-endpoint.us-east-1.rds.amazonaws.com -u repl_azure -p
    ```

18. **Verify replication on Azure MySQL**:
    ```sql
    SHOW REPLICA STATUS\G
    ```

    Look for:
    - `Replica_IO_Running: Yes`
    - `Replica_SQL_Running: Yes`
    - `Seconds_Behind_Master: 0` (or low number)

### Phase 7: Deploy Gitea Applications

19. **Deploy Gitea on AWS** (primary):
    ```bash
    cd ANSIBLE-INFRA-DEMOGITEA
    ansible-playbook -i inventory.ini playbook.yml
    ```

20. **Deploy Gitea on Azure** (standby):
    ```bash
    cd ANSIBLE-AZ-DEMOGITEA
    ansible-playbook -i inventory.ini playbook.yml
    ```

## Failover Process

### Planned Failover (AWS → Azure)

1. Stop writes on AWS Gitea
2. Wait for Azure replica to catch up: `SHOW REPLICA STATUS\G` → `Seconds_Behind_Master: 0`
3. Stop replication on Azure: `STOP REPLICA;`
4. Make Azure MySQL writable (already is, no action needed)
5. Update DNS/Load Balancer to point to Azure Gitea
6. Start Azure Gitea
7. Verify application functionality

### Failback (Azure → AWS)

1. Ensure AWS RDS is running and binlog enabled
2. Get Azure binlog position
3. Configure reverse replication (Azure → AWS)
4. Wait for sync
5. Switch traffic back to AWS

## Troubleshooting

### VPN Connection Issues

**Tunnel status DOWN**:
```bash
# Check AWS Security Groups allow UDP 500, 4500
# Check Azure NSG allows UDP 500, 4500
# Verify shared key matches on both sides
# Check BGP ASN is 65000 on both sides
```

### Replication Issues

**Replica_IO_Running: No**:
```bash
# Check network connectivity
ping your-rds-endpoint.us-east-1.rds.amazonaws.com  # From Azure VM
# Check replication user permissions
# Verify master_log_file and master_log_position are correct
```

**Replica_SQL_Running: No**:
```sql
-- Check error:
SHOW REPLICA STATUS\G
-- Look for Last_SQL_Error

-- Skip problematic statement (if safe):
SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
START REPLICA;
```

### Binlog Position Drift

If replication breaks and you need to resync:

1. Stop Azure Gitea
2. Get current AWS binlog position: `SHOW MASTER STATUS;`
3. Reset replica on Azure:
   ```sql
   STOP REPLICA;
   RESET REPLICA;
   CHANGE REPLICATION SOURCE TO
     SOURCE_HOST='your-rds-endpoint',
     SOURCE_USER='repl_azure',
     SOURCE_PASSWORD='SecurePassword123!',
     SOURCE_LOG_FILE='mysql-bin.000123',
     SOURCE_LOG_POS=4567;
   START REPLICA;
   ```
4. Verify: `SHOW REPLICA STATUS\G`

## Cost Considerations

### AWS Changes
- **RDS Backup Storage**: 7 days retention (binlog requires backup_retention_period ≥ 1)
  - First 100% of DB size is free
  - Example: 10 GB DB = 70 GB backup storage → ~$1.75/month
- **VPN Gateway**: $0.05/hour = ~$36/month
- **Data Transfer**: $0.09/GB for VPN traffic

### Azure Changes
- **VPN Gateway**: VpnGw1 SKU = ~$140/month
- **MySQL Flexible Server**: Already included (B1ms tier)

### Total Monthly Cost Increase
- AWS: ~$38/month
- Azure: ~$140/month
- **Total: ~$178/month for failover capability**

## Maintenance

### Regular Checks
- Monitor VPN tunnel status daily
- Check replication lag: `SHOW REPLICA STATUS\G` → `Seconds_Behind_Master`
- Review AWS RDS backup storage usage
- Test failover procedure quarterly

### Updating Gitea
1. Stop replication temporarily
2. Update AWS Gitea first
3. Test thoroughly
4. Resume replication
5. Let Azure sync
6. Update Azure Gitea

## Security Notes

- Use strong passwords for `replication_user` and `vpn_shared_key`
- Store sensitive values in AWS Secrets Manager / Azure Key Vault
- Restrict RDS security group to only allow Azure VPN CIDR (10.1.0.0/16)
- Enable encryption in transit for MySQL connections
- Rotate VPN shared key annually

## References

- AWS VPN Documentation: https://docs.aws.amazon.com/vpn/
- Azure VPN Gateway: https://learn.microsoft.com/en-us/azure/vpn-gateway/
- MySQL Replication: https://dev.mysql.com/doc/refman/8.0/en/replication.html
- Gitea Documentation: https://docs.gitea.io/
