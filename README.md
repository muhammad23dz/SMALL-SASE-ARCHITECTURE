# SASE-as-Code Lab Environment

A complete Secure Access Service Edge (SASE) lab environment implemented entirely through Infrastructure as Code (IaC). This lab demonstrates modern Zero Trust network security principles with no legacy technology, no open inbound ports, and identity-centric access control.

## Architecture Overview

This lab implements a comprehensive SASE architecture with the following components:

### Phase 1: Underlay & Overlay (Simulated WAN)
- **Containerlab**: Network topology with 3 VyOS routers (HQ, Branch, Remote Worker)
- **BGP**: E-BGP routing over simulated public internet bridge
- **WireGuard**: Full-mesh SD-WAN overlay network
- **PBR**: Policy-Based Routing for application traffic steering

### Phase 2: Identity & Access Management
- **Keycloak**: Central Identity Provider (IdP) with OIDC
- **Groups**: Engineering (full access) and Contractors (limited access)
- **Users**: Pre-configured test users for each group

### Phase 3: ZTNA, SWG, & CASB (Cloudflare Zero Trust)
- **Cloudflare Tunnels**: Zero Trust Network Access with no open inbound ports
- **ZTNA Policies**: Identity-based access control with MFA
- **SWG/CASB**: DNS filtering and SaaS application controls
- **GenAI Controls**: HTTP Gateway policies for AI application visibility

### Phase 4: FWaaS & IPS (Edge Security)
- **OPNsense**: Next-generation firewalls behind VyOS routers
- **Suricata**: Inline IPS mode with ET Pro telemetry rules
- **Ansible**: Automated firewall configuration and IPS management

### Phase 5: Converged Visibility (SIEM/XDR)
- **Wazuh**: Security information and event management
- **Grafana**: Unified dashboard for security correlation
- **Loki/Promtail**: Log aggregation and collection
- **Integration**: Log forwarding from all security components

## Prerequisites

### Hardware Requirements
- **RAM**: 16GB+ minimum (24GB+ recommended)
- **CPU**: 4+ cores (8+ recommended)
- **Disk**: 50GB+ free space
- **OS**: Linux host (Ubuntu 20.04+ recommended)

### Software Requirements
```bash
# Install required tools
sudo apt update
sudo apt install -y docker.io docker-compose containerlab ansible terraform

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Python dependencies
pip3 install ansible-netconf ansible-pylibssh paramiko requests
```

### Cloudflare Account
- Cloudflare account with a registered domain
- Cloudflare API token with appropriate permissions
- Cloudflare Account ID

## Deployment Guide

### Step 1: Initial Setup

```bash
# Clone or navigate to the project directory
cd sase-lab

# Verify directory structure
find . -type f | sort
```

### Step 2: Generate WireGuard Keys

```bash
# Generate WireGuard keys for each site
cd ansible/roles/vyos/vars

# HQ keys
wg genkey | tee hq_private.key | wg pubkey > hq_public.key
echo "HQ Private Key: $(cat hq_private.key)"
echo "HQ Public Key: $(cat hq_public.key)"

# Branch keys
wg genkey | tee branch_private.key | wg pubkey > branch_public.key
echo "Branch Private Key: $(cat branch_private.key)"
echo "Branch Public Key: $(cat branch_public.key)"

# Remote keys
wg genkey | tee remote_private.key | wg pubkey > remote_public.key
echo "Remote Private Key: $(cat remote_private.key)"
echo "Remote Public Key: $(cat remote_public.key)"

# Update vars/main.yml with the generated keys
# Replace the placeholder values with your actual keys
```

### Step 3: Configure Terraform Variables

```bash
cd terraform

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your Cloudflare credentials
nano terraform.tfvars
```

Required variables in `terraform.tfvars`:
```hcl
cloudflare_api_token = "your_cloudflare_api_token_here"
cloudflare_account_id = "your_cloudflare_account_id_here"
cloudflare_domain     = "your-domain.com"
keycloak_client_id     = "cloudflare-zero-trust"
keycloak_client_secret = "cloudflare-secret-change-in-production"
keycloak_issuer_url    = "http://keycloak.sase-lab.local:8080/realms/sase-lab"
wazuh_endpoint = "wazuh-manager.sase-lab.local"
enable_logpush = false  # Set to true after Wazuh is deployed
```

### Step 4: Deploy Phase 1 - Network Infrastructure

```bash
# Deploy Containerlab topology
cd containerlab
sudo clab deploy -t clab.yml

# Wait for containers to start (2-3 minutes)
sudo clab inspect

# Verify VyOS routers are accessible
docker exec -it clab-sase-lab-hq-vyos bash
exit

# Apply Ansible configuration
cd ../ansible
ansible-playbook -i inventory.ini site.yml --ask-vault-pass

# Verify BGP sessions
docker exec clab-sase-lab-hq-vyos vtysh -c "show ip bgp summary"
docker exec clab-sase-lab-branch-vyos vtysh -c "show ip bgp summary"
docker exec clab-sase-lab-remote-vyos vtysh -c "show ip bgp summary"

# Verify WireGuard connections
docker exec clab-sase-lab-hq-vyos show interfaces wireguard wg0
```

### Step 5: Deploy Phase 2 - Identity Provider

```bash
# Deploy Keycloak
cd ../docker/keycloak
docker-compose up -d

# Wait for Keycloak to start (2-3 minutes)
docker-compose ps

# Import the realm configuration
# Access Keycloak at http://localhost:8080
# Login with admin/admin123
# Import the realm-export.json file

# Verify users and groups
# Navigate to the sase-lab realm
# Check Engineering and Contractors groups
# Check test users: eng-admin, eng-user1, contractor-user1, contractor-user2
```

### Step 6: Deploy Phase 3 - Cloudflare Zero Trust

```bash
# Deploy Terraform configuration
cd ../../terraform
terraform init
terraform plan
terraform apply

# Wait for Terraform to complete (2-3 minutes)
# Verify Cloudflare Zero Trust resources in your Cloudflare dashboard

# Note the tunnel token for Cloudflared installation
terraform output -raw tunnel_token
```

### Step 7: Deploy Phase 4 - Firewalls and IPS

```bash
# Deploy OPNsense and Suricata
cd ../docker/opnsense
docker-compose up -d

# Wait for OPNsense to start (3-5 minutes)
docker-compose ps

# Apply Ansible firewall configuration
cd ../../ansible
ansible-playbook -i inventory.ini site.yml --limit opnsense_firewalls

# Verify Suricata is running
docker logs sase-hq-suricata
docker logs sase-branch-suricata
```

### Step 8: Deploy Phase 5 - SIEM and Monitoring

```bash
# Deploy Wazuh and Grafana stack
cd ../docker/wazuh
docker-compose up -d

# Wait for all services to start (3-5 minutes)
docker-compose ps

# Access Grafana
# http://localhost:3000
# Login with admin/admin123

# Access Wazuh Dashboard
# http://localhost:5601
# Login with admin/admin123
```

### Step 9: Enable Log Integration

```bash
# Update Terraform to enable logpush
cd ../../terraform
sed -i 's/enable_logpush = false/enable_logpush = true/' terraform.tfvars

# Apply Terraform changes
terraform plan
terraform apply

# Restart log services if needed
cd ../docker/wazuh
docker-compose restart promtail
```

### Step 10: Cloudflared Installation

```bash
# Install cloudflared on the application servers
# For the wiki application
docker exec clab-sase-lab-wiki-app sh -c "
  apk add --no-cache curl
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
"

# Get the tunnel token from Terraform output
TUNNEL_TOKEN=$(cd terraform && terraform output -raw tunnel_token)

# Start cloudflared on the wiki app
docker exec -d clab-sase-lab-wiki-app cloudflared tunnel run --token $TUNNEL_TOKEN

# Repeat for Grafana app
docker exec clab-sase-lab-grafana-app sh -c "
  apk add --no-cache curl
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
"

docker exec -d clab-sase-lab-grafana-app cloudflared tunnel run --token $TUNNEL_TOKEN
```

## Verification Steps

### Network Connectivity
```bash
# Test BGP routes
docker exec clab-sase-lab-hq-vyos vtysh -c "show ip route bgp"

# Test WireGuard connectivity
docker exec clab-sase-lab-hq-vyos ping -c 3 10.100.0.2
docker exec clab-sase-lab-hq-vyos ping -c 3 10.100.0.3

# Test PBR
docker exec clab-sase-lab-hq-vyos show policy route PBR-INTERNAL
```

### Identity Provider
```bash
# Test Keycloak health
curl -f http://localhost:8080/health/ready

# Test OIDC endpoint
curl http://localhost:8080/realms/sase-lab/.well-known/openid-configuration
```

### Cloudflare Zero Trust
```bash
# Test tunnel connectivity
# Check Cloudflare Zero Trust dashboard for tunnel status

# Test ZTNA access
# Access wiki.your-domain.com (should redirect to Keycloak login)
# Access grafana.your-domain.com (should redirect to Keycloak login)
```

### Firewall and IPS
```bash
# Check OPNsense status
docker exec sase-hq-opnsense opnsense-shell -c "pfctl -sr"

# Check Suricata status
docker logs sase-hq-suricata | grep "Suricata initialized"
```

### SIEM Integration
```bash
# Check Wazuh status
curl -f http://localhost:55000/health

# Check Grafana dashboards
# Access http://localhost:3000
# Verify SASE Security Correlation Dashboard is populated
```

## Architecture Details

### Network Topology
```
Internet (198.51.100.0/24)
    ├── HQ-VyOS (198.51.100.10) ── WireGuard ── Branch-VyOS (198.51.100.20)
    │    └── OPNsense (10.1.0.2) ── Apps (10.1.0.10, 10.1.0.11)
    │
    ├── Branch-VyOS (198.51.100.20) ── WireGuard ── Remote-VyOS (198.51.100.30)
    │    └── OPNsense (10.2.0.2)
    │
    └── Remote-VyOS (198.51.100.30)
```

### WireGuard Overlay
```
WireGuard Network (10.100.0.0/24)
    ├── HQ-VyOS (10.100.0.1)
    ├── Branch-VyOS (10.100.0.2)
    └── Remote-VyOS (10.100.0.3)
```

### Access Policies
- **Engineering Group**: Full access to all applications, GenAI allowed
- **Contractor Group**: Limited access, GenAI blocked
- **Default Deny**: All other access denied

## Troubleshooting

### Containerlab Issues
```bash
# Destroy and redeploy lab
sudo clab destroy -t containerlab/clab.yml
sudo clab deploy -t containerlab/clab.yml

# Check container logs
docker logs clab-sase-lab-hq-vyos
```

### Ansible Issues
```bash
# Test connectivity
ansible -i ansible/inventory.ini vyos_routers -m ping

# Run with verbose output
ansible-playbook -i ansible/inventory.ini ansible/site.yml -vvv
```

### Terraform Issues
```bash
# Check state
terraform state list

# Reconfigure
terraform plan -refresh-only

# Destroy resources
terraform destroy
```

### Docker Issues
```bash
# Check container status
docker ps -a

# Restart services
docker-compose restart

# View logs
docker-compose logs -f
```

## Security Considerations

### Production Deployment Notes
1. **Change Default Passwords**: Update all default credentials before production deployment
2. **Use Strong Encryption**: Generate production-grade WireGuard keys
3. **Implement RBAC**: Configure proper role-based access control
4. **Enable MFA**: Require multi-factor authentication for all access
5. **Network Segmentation**: Implement additional VLANs for production environments
6. **Backup Strategy**: Implement regular configuration backups
7. **Monitoring**: Enable comprehensive monitoring and alerting
8. **Compliance**: Ensure configuration meets organizational compliance requirements

### Zero Trust Principles Implemented
- **Verify Explicitly**: All access requests are authenticated and authorized
- **Least Privilege**: Users have minimum required access
- **Assume Breach**: Continuous monitoring and threat detection
- **Identity-Centric**: Access based on identity, not network location
- **Micro-Segmentation**: Network segmentation between components

## Cleanup

To destroy the entire lab environment:

```bash
# Destroy Terraform resources
cd terraform
terraform destroy

# Stop Docker services
cd ../docker
docker-compose -f keycloak/docker-compose.yml down
docker-compose -f opnsense/docker-compose.yml down
docker-compose -f wazuh/docker-compose.yml down

# Destroy Containerlab lab
cd ../containerlab
sudo clab destroy -t clab.yml

# Remove Docker volumes
docker volume prune -f

# Remove WireGuard keys
rm -f ansible/roles/vyos/vars/*_private.key ansible/roles/vyos/vars/*_public.key
```

## Additional Resources

- [Containerlab Documentation](https://containerlab.dev/)
- [VyOS Documentation](https://docs.vyos.io/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Cloudflare Zero Trust Documentation](https://developers.cloudflare.com/cloudflare-one/)
- [OPNsense Documentation](https://docs.opnsense.org/)
- [Wazuh Documentation](https://documentation.wazuh.com/)
- [Grafana Documentation](https://grafana.com/docs/)

## Contributing

This is a reference implementation for SASE architecture. Modify and extend based on your specific requirements and security policies.

## License

This project is provided as-is for educational and testing purposes.