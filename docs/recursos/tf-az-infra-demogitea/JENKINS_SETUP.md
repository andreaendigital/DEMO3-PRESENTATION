# Jenkins Setup for Azure Deployment

## Overview

This document describes the Jenkins configuration required for automated Azure infrastructure deployment.

## Prerequisites

- Jenkins server with Azure CLI
- Azure service principal credentials
- SSH keys for VM access
- Terraform installed

## Pipeline Configuration

### Required Plugins
- Azure Credentials Plugin
- Terraform Plugin
- SSH Agent Plugin

### Credentials Setup
- `azure-service-principal` - Azure authentication
- `ssh-private-key` - VM access key
- `mysql-admin-password` - Database credentials

## Pipeline Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| DEPLOYMENT_MODE | Infrastructure mode | full-stack |
| APPLY_TERRAFORM | Execute terraform apply | true |
| DEPLOY_ANSIBLE | Run Ansible playbooks | true |

## Troubleshooting

### Common Issues
- Azure authentication failures
- Terraform state conflicts
- SSH connectivity problems

## Related Documentation

- [Main README](./README.md)
- [Failover Architecture](./FAILOVER_ARCHITECTURE.md)