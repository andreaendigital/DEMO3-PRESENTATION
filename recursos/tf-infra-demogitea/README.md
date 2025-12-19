# Gitea Infrastructure

A complete DevOps solution for deploying Gitea (self-hosted Git service) on AWS using Infrastructure as Code (IaC) and automated CI/CD pipelines.

## 🏗️ Architecture Overview

This project implements a modern DevOps architecture with:

- **Infrastructure as Code**: Terraform modules for AWS resource provisioning
- **Configuration Management**: Ansible for application deployment and configuration
- **CI/CD Pipeline**: Jenkins for automated deployment orchestration
- **Cloud Platform**: AWS with multi-AZ deployment for high availability

## 🚀 Features

- **Automated Infrastructure Provisioning**: Complete AWS infrastructure setup with Terraform
- **Scalable Architecture**: VPC with public/private subnets, Application Load Balancer, and RDS
- **Secure Deployment**: Security groups, IAM roles, and encrypted storage
- **Automated Application Deployment**: Ansible playbooks for Flask application setup
- **CI/CD Integration**: Jenkins pipeline with parameterized builds
- **Service Management**: Systemd service configuration for production deployment
- **Observability & Monitoring**: Integrated Splunk Observability Cloud for infrastructure and application monitoring

## 📋 Prerequisites

- AWS Account with appropriate permissions
- Jenkins server with required plugins
- Terraform >= 1.0
- Ansible >= 2.9
- Git access to repositories

## 🛠️ Infrastructure Components

### AWS Resources

| Component           | Description               | Configuration                           |
| ------------------- | ------------------------- | --------------------------------------- |
| **VPC**             | Virtual Private Cloud     | 10.0.0.0/16 CIDR                        |
| **Subnets**         | Public/Private subnets    | Multi-AZ (us-east-1a, us-east-1b)       |
| **EC2**             | Application server        | t3.small (Free Tier compatible)         |
| **RDS**             | MySQL database            | db.t3.micro with automated backups      |
| **ALB**             | Application Load Balancer | HTTP/HTTPS traffic distribution         |
| **Security Groups** | Network security          | SSH, HTTP, HTTPS, and application ports |

### Terraform Modules

```
infra/
├── networking/          # VPC, subnets, routing
├── security-groups/     # Security group configurations
├── ec2/                # EC2 instance and key pairs
├── rds/                # RDS MySQL database
├── load-balancer/      # Application Load Balancer
├── load-balancer-target-group/  # ALB target groups
├── s3/                 # S3 bucket for remote state
└── monitoring.tf       # Splunk Observability Cloud integration
└── extrafiles.tf       # Various Terraform files such as main, provider, outputs, etc
```

## 🔧 Setup Instructions

### 1. Jenkins Configuration

#### Required Credentials

Configure these credentials in Jenkins:

| Credential ID          | Type            | Description                           |
| ---------------------- | --------------- | ------------------------------------- |
| `aws-jenkins-carprice` | AWS Credentials | AWS access keys for Terraform/Ansible |
| `ansible-ssh-key`      | SSH Private Key | EC2 instance access key               |
| `github-andrea-token`  | Secret Text     | GitHub access token                   |

#### Required Plugins

- AWS Credentials Plugin
- SSH Agent Plugin
- Git Plugin
- Pipeline Plugin

### 2. AWS Prerequisites

1. **S3 Bucket**: Create bucket for Terraform remote state

   ```bash
   aws s3 mb s3://infracar-terraform-state
   ```

2. **IAM Permissions**: Ensure AWS credentials have permissions for:
   - EC2 (instances, security groups, key pairs)
   - VPC (networking components)
   - RDS (database instances)
   - ELB (load balancers)
   - S3 (state storage)

### 3. Repository Setup

Clone the required repositories:

```bash
# Infrastructure repository
git clone https://github.com/andreaendigital/tf-infra-demoCar

# Configuration management repository
git clone https://github.com/andreaendigital/configManagement-carPrice
```

## 🚀 Deployment

### Jenkins Pipeline Parameters

| Parameter           | Default | Description                               |
| ------------------- | ------- | ----------------------------------------- |
| `PLAN_TERRAFORM`    | `true`  | Run terraform plan to preview changes     |
| `APPLY_TERRAFORM`   | `true`  | Apply infrastructure changes              |
| `DEPLOY_ANSIBLE`    | `true`  | Deploy Flask application with Ansible     |
| `DESTROY_TERRAFORM` | `false` | Destroy infrastructure (use with caution) |

### Pipeline Stages

1. **Clone Repositories**: Fetch infrastructure and configuration code
2. **Terraform Init**: Initialize Terraform with remote state
3. **Terraform Plan**: Preview infrastructure changes
4. **Terraform Apply**: Provision AWS resources (with approval gate)
5. **Generate Ansible Inventory**: Create dynamic inventory from Terraform output
6. **Run Ansible Playbook**: Deploy and configure Flask application
7. **Deploy Monitoring**: Install Splunk OpenTelemetry Collector via Ansible
8. **Reload Service**: Restart application service with updated configuration
9. **Post-Deploy Verification**: Verify application and monitoring service status
10. **Send Metrics**: Pipeline success/failure metrics sent to Splunk Observability

### Manual Deployment

```bash
# 1. Initialize Terraform
cd infra
terraform init

# 2. Plan infrastructure changes
terraform plan -out=tfplan

# 3. Apply infrastructure
terraform apply tfplan

# 4. Run Ansible deployment
cd ../
ansible-playbook -i inventory.ini playbook.yml
```

## 🔍 Monitoring & Verification

### Observability & Monitoring

**Splunk Observability Cloud Integration:**

- **Infrastructure Metrics**: EC2 CPU, memory, disk, network monitoring
- **Application Metrics**: Flask app performance metrics (ports 3000, 5002)
- **Pipeline Metrics**: Jenkins deployment success/failure tracking
- **Real-time Dashboards**: https://app.us1.signalfx.com

**Monitoring Variables:**

```hcl
# Terraform Variables (infra/monitoring.tf)
variable "splunk_observability_token" {
  description = "Splunk Observability Cloud token"
  type        = string
  default     = "PZuf3J0L2Op_Qj9hpAJzlw"
  sensitive   = true
}

variable "splunk_realm" {
  description = "Splunk realm"
  type        = string
  default     = "us1"
}
```

**Ansible Monitoring Role:**

```yaml
# configManagement-carPrice/roles/splunk_monitoring/vars/main.yml
splunk_token: "PZuf3J0L2Op_Qj9hpAJzlw"
splunk_realm: "us1"
```

### Application Health Check

```bash
# Check service status
systemctl status carprice
systemctl status splunk-otel-collector

# View application logs
journalctl -u carprice -f
journalctl -u splunk-otel-collector -f

# Test application endpoints
curl http://<EC2_PUBLIC_IP>:3000/health  # Frontend
curl http://<EC2_PUBLIC_IP>:5002/health  # Backend
curl http://<EC2_PUBLIC_IP>:5002/metrics/json  # Metrics
```

### Infrastructure Verification

```bash
# Check Terraform state
terraform show

# List AWS resources
aws ec2 describe-instances --filters "Name=tag:Project,Values=infraGitea"

# Verify monitoring configuration
terraform output splunk_config
```

## 📁 Project Structure

```
tf-infra-demoCar/
├── infra/                      # Terraform infrastructure code
│   ├── modules/               # Reusable Terraform modules
│   ├── main.tf               # Main infrastructure configuration
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values
│   ├── terraform.tfvars      # Variable values
│   ├── monitoring.tf         # Splunk Observability configuration
│   └── remote_backend_s3.tf  # Remote state configuration
├── Jenkinsfile               # CI/CD pipeline definition
├── .gitignore               # Git ignore patterns
└── README.md                # This file
```

## 🔒 Security Considerations

- **Network Security**: Private subnets for database, security groups with minimal access
- **Access Control**: IAM roles and policies following least privilege principle
- **Data Protection**: RDS encryption at rest, secure credential management
- **Infrastructure Security**: Regular security group audits, VPC flow logs

## 🚨 Troubleshooting

### Common Issues

| Issue                     | Solution                                            |
| ------------------------- | --------------------------------------------------- |
| Terraform state lock      | `terraform force-unlock <LOCK_ID>`                  |
| Ansible connection failed | Verify SSH key and security groups                  |
| Service startup failed    | Check systemd service configuration                 |
| AWS credentials error     | Verify IAM permissions and credential configuration |

### Logs Location

- **Jenkins**: Jenkins console output
- **Terraform**: Local `.terraform/` directory
- **Ansible**: Ansible playbook output
- **Application**: `/var/log/syslog` and `journalctl -u carprice`
- **Monitoring**: `journalctl -u splunk-otel-collector`
- **Splunk Dashboards**: https://app.us1.signalfx.com

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit changes (`git commit -am 'Add improvement'`)
4. Push to branch (`git push origin feature/improvement`)
5. Create Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For issues and questions:

- Create an issue in the GitHub repository
- Review the troubleshooting section
- Check Jenkins console logs for detailed error information

---

**Built with ❤️ using Terraform, Ansible, and Jenkins**
