# Gitea Git Service - Ansible Deployment

## Overview

This project provides **fully automated deployment** of Gitea, a lightweight Git service, using Ansible configuration management. The deployment follows official Gitea best practices and requires **NO MANUAL CONFIGURATION** by the user after deploy.

## ✨ Key Features

- ✅ **Fully Automated Setup**: No web installer, no manual configuration required
- ✅ **Production-Ready**: MySQL RDS database pre-configured
- ✅ **Secure by Default**: Auto-generated secrets, proper file permissions
- ✅ **Auto-Start**: Systemd service with restart policies
- ✅ **Official Best Practices**: Follows [Gitea official documentation](https://docs.gitea.com/installation/install-from-binary)

## Architecture

The application consists of the following components:

- **Gitea Service**: Self-hosted Git service with web interface on port 3000
- **Database**: MySQL RDS (configured automatically)
- **Service Management**: Systemd with auto-restart and security hardening
- **User Management**: Optional pre-configured admin user

## Prerequisites

- **Ansible**: Version 2.9 or higher
- **Python**: Version 3.6 or higher
- **Terraform**: For infrastructure provisioning (EC2 instance)
- **SSH Access**: Private key for EC2 instance authentication
- **AWS Account**: With appropriate permissions for EC2 deployment

## Project Structure

```
configManagement-carPrice/
├── roles/deploy/                    # Ansible deployment role
│   ├── tasks/main.yml              # Complete deployment workflow
│   └── templates/                  # Systemd service templates
│       └── gitea.service           # Gitea Git service configuration
├── ansible.cfg                     # Ansible configuration settings
├── generate_inventory.sh           # Dynamic inventory generation script
├── inventory.ini                   # Ansible inventory file (auto-generated)
├── playbook.yml                   # Main deployment playbook
└── README.md                      # Project documentation
```

## Deployment Instructions

### Step 1: Infrastructure Setup

Ensure your EC2 infrastructure is provisioned via Terraform in the parent `infra/` directory.

### Step 2: Generate Dynamic Inventory

```bash
chmod +x generate_inventory.sh
./generate_inventory.sh
```

This script automatically retrieves the EC2 public IP from Terraform state and generates the Ansible inventory.

### Step 3: Execute Deployment

```bash
# Dry run to validate configuration
ansible-playbook playbook.yml --check

# Production deployment
ansible-playbook playbook.yml
```

### Step 4: Verify Deployment

After successful deployment, verify services are running:

```bash
# Check service status
ansible infraCar -m shell -a "systemctl status gitea"

# Test Gitea service
curl http://<EC2_IP>:3000
```

## Service Configuration

### Gitea Service

- **Port**: 3000
- **User**: git (system user, following official docs)
- **Working Directory**: /var/lib/gitea
- **Configuration**: /etc/gitea/app.ini
- **Database**: MySQL RDS (automatically configured)
- **Auto-restart**: Enabled via systemd with 2s restart delay
- **Install Lock**: ENABLED (prevents web installer access)

### Security Features

- ✅ Auto-generated `SECRET_KEY` and `INTERNAL_TOKEN`
- ✅ Proper file permissions (640 for config, 750 for directories)
- ✅ Systemd security hardening (`ProtectSystem`, `PrivateTmp`, etc.)
- ✅ Database credentials from secure variables

### Admin User (Optional)

You can pre-configure an admin user by setting these variables in `group_vars/all.yml`:

```yaml
gitea_admin_username: "admin"
gitea_admin_password: "SecurePassword123!"
gitea_admin_email: "admin@company.com"
```

If not configured, the first user to register will automatically become admin.

## 📚 Configuration Details

For a comprehensive explanation of the automatic configuration, see [CONFIGURACION_AUTOMATICA.md](./CONFIGURACION_AUTOMATICA.md).

### Key Configuration Highlights

1. **INSTALL_LOCK = true**: Disables web installer, application starts immediately
2. **Pre-configured Database**: MySQL RDS connection ready to use
3. **Generated Secrets**: Unique keys per installation
4. **Systemd Integration**: Auto-start on boot, auto-restart on failure

## Troubleshooting

### Common Issues

**SSH Connection Failed**

```bash
# Verify SSH key permissions
chmod 600 ~/.ssh/demoCar-jenkins_key.pem

# Test SSH connectivity
ssh -i ~/.ssh/demoCar-jenkins_key.pem ec2-user@<EC2_IP>
```

**Service Start Failures**

```bash
# Check service logs
ansible infraCar -m shell -a "journalctl -u gitea -f"

# Verify configuration
ansible infraCar -m shell -a "cat /etc/gitea/app.ini"

# Check database connectivity
ansible infraCar -m shell -a "/usr/local/bin/gitea doctor check --config /etc/gitea/app.ini"
```

**Database Connection Issues**

```bash
# Verify RDS is accessible
ansible infraCar -m shell -a "nc -zv <RDS_ENDPOINT> 3306"

# Check database credentials in app.ini
ansible infraCar -m shell -a "grep -A5 '\[database\]' /etc/gitea/app.ini"
```

## 🎯 What Makes This Configuration Special

According to [Gitea's official documentation](https://docs.gitea.com/installation/install-from-binary), the **recommended production setup** requires:

1. ✅ **Disabled Web Installer** (`INSTALL_LOCK = true`) - ✓ Implemented
2. ✅ **Auto-generated Secrets** - ✓ Using `gitea generate secret`
3. ✅ **Proper Directory Structure** - ✓ Follows official layout
4. ✅ **Correct Permissions** - ✓ 750/640 as documented
5. ✅ **Systemd Service** - ✓ With security hardening
6. ✅ **Pre-configured Database** - ✓ MySQL RDS ready

**Result**: Gitea is production-ready immediately after ansible-playbook completes. No manual steps required.

## 📖 Additional Resources

- [Official Gitea Documentation](https://docs.gitea.com/)
- [Installation from Binary Guide](https://docs.gitea.com/installation/install-from-binary)
- [Configuration Cheat Sheet](https://docs.gitea.com/administration/config-cheat-sheet)
- [CONFIGURACION_AUTOMATICA.md](./CONFIGURACION_AUTOMATICA.md) - Detailed explanation (Spanish)

**Inventory Generation Issues**

```bash
# Verify Terraform state
cd ../infra && terraform output ec2_public_ip
```

## Security Considerations

- SSH keys are stored locally and referenced via absolute paths
- Services run under `ec2-user` with minimal privileges
- Systemd services include restart policies for high availability
- Monitoring tokens are embedded for demonstration purposes

## Maintenance

### Service Management

```bash
# Restart service
ansible infraCar -m systemd -a "name=gitea state=restarted" --become

# View service status
ansible infraCar -m systemd -a "name=gitea" --become
```

### Log Management

```bash
# View application logs
ansible infraCar -m shell -a "journalctl -u gitea --since '1 hour ago'"
```

## Contributing

1. Follow Ansible best practices for task organization
2. Test deployments in development environment before production
3. Update documentation for any configuration changes
4. Ensure idempotent task execution

## License

This project is developed for educational purposes as part of DevOps coursework.

---

**Author**: DevOps Engineering Student  
**Course**: Infrastructure as Code & Configuration Management  
**Institution**: [Your Institution Name]

<!-- Version: 1.0.1 - Updated GitHub templates -->
