# Azure Infrastructure for Gitea

## Overview

This repository contains Terraform infrastructure code for deploying Gitea on Azure as part of the multi-cloud disaster recovery solution.

## Architecture

- **Virtual Network**: 10.1.0.0/16
- **Virtual Machines**: Gitea application and MySQL database
- **Load Balancer**: Azure Load Balancer for high availability
- **VPN Gateway**: Site-to-site connection with AWS

## Deployment Modes

1. **FULL_STACK** - Complete infrastructure deployment
2. **REPLICA_ONLY** - Database replication only
3. **FAILOVER** - Emergency recovery mode

## Quick Start

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply
```

## Related Documentation

- [Failover Architecture](./FAILOVER_ARCHITECTURE.md)
- [Jenkins Setup](./JENKINS_SETUP.md)
- [Repository Relationships](./REPOSITORY_RELATIONSHIPS.md)