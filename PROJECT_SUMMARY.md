# SASE-as-Code Lab - Project Summary

## Project Overview

This is a complete Secure Access Service Edge (SASE) lab environment implemented entirely through Infrastructure as Code (IaC). The project demonstrates modern Zero Trust network security principles with no legacy technology, no open inbound ports, and identity-centric access control.

## Completed Phases

### ✅ Phase 1: Underlay & Overlay (Network Infrastructure)
- **Containerlab topology** with 3 VyOS routers (HQ, Branch, Remote Worker)
- **E-BGP routing** over simulated public internet bridge
- **WireGuard full-mesh SD-WAN** overlay network
- **Policy-Based Routing (PBR)** for application traffic steering
- **Ansible automation** for VyOS configuration

### ✅ Phase 2: Identity & Access Management
- **Keycloak** deployment with Docker Compose
- **OIDC provider** configuration for Cloudflare Zero Trust
- **Pre-configured realm** with Engineering and Contractors groups
- **Test users** for each group with appropriate roles

### ✅ Phase 3: ZTNA, SWG, & CASB (Cloudflare Zero Trust)
- **Cloudflare Tunnels** for zero inbound ports
- **ZTNA access policies** with identity-based control
- **SWG/CASB DNS filtering** for malicious domains
- **GenAI HTTP Gateway policies** for AI application visibility
- **Terraform automation** for all Cloudflare resources

### ✅ Phase 4: FWaaS & IPS (Edge Security)
- **OPNsense** firewalls behind VyOS routers
- **Suricata IPS** in inline mode with ET Pro rules
- **Ansible automation** for firewall rules and IPS configuration
- **Syslog forwarding** to SIEM integration

### ✅ Phase 5: Converged Visibility (SIEM/XDR)
- **Wazuh** security information and event management
- **Grafana** unified dashboard for security correlation
- **Loki/Promtail** log aggregation and collection
- **Cross-platform log integration** from all security components

## Project Structure

```
sase-lab/
├── containerlab/
│   └── clab.yml                    # Network topology definition
├── ansible/
│   ├── inventory.ini               # Ansible inventory
│   ├── site.yml                    # Main playbook
│   └── roles/
│       ├── vyos/
│       │   ├── tasks/main.yml      # VyOS configuration tasks
│       │   └── vars/main.yml       # Site-specific variables
│       └── opnsense/
│           └── tasks/main.yml      # OPNsense configuration tasks
├── terraform/
│   ├── main.tf                     # Terraform configuration
│   ├── variables.tf                # Variable definitions
│   └── terraform.tfvars.example    # Variable template
├── docker/
│   ├── keycloak/
│   │   ├── docker-compose.yml     # Keycloak deployment
│   │   └── realm-export.json      # Pre-configured realm
│   ├── opnsense/
│   │   ├── docker-compose.yml     # OPNsense deployment
│   │   └── suricata-config/        # Suricata configurations
│   └── wazuh/
│       ├── docker-compose.yml      # Wazuh/Grafana stack
│       ├── wazuh-config/           # Wazuh configurations
│       ├── grafana-config/         # Grafana configurations
│       ├── loki-config/            # Loki configuration
│       └── promtail-config/        # Promtail configuration
├── generate-wg-keys.sh             # WireGuard key generation script
├── README.md                       # Comprehensive deployment guide
└── .gitignore                      # Git ignore rules
```

## Key Features

### Zero Trust Principles
- **Identity-Centric**: Access determined by OIDC tokens, not IP addresses
- **No Inbound Ports**: All applications published via outbound reverse tunnels
- **Least Privilege**: Users have minimum required access
- **Verify Explicitly**: All access requests authenticated and authorized
- **Assume Breach**: Continuous monitoring and threat detection

### Modern Technology Stack
- **WireGuard**: Modern cryptography for site-to-site mesh overlay
- **OIDC**: OpenID Connect for identity federation
- **Cloudflare Zero Trust**: ZTNA, SWG, CASB capabilities
- **Suricata**: Modern IDS/IPS with ET Pro telemetry
- **Wazuh**: Open-source SIEM/XDR platform
- **Grafana**: Unified security correlation dashboard

### Automation & IaC
- **100% Infrastructure as Code**: No GUI clicking required
- **Terraform**: Cloudflare Zero Trust infrastructure
- **Ansible**: Network device configuration
- **Containerlab**: Network topology simulation
- **Docker Compose**: Application deployment

## Security Standards

### No Legacy Technology
- ❌ No IKEv1/IPSec VPNs
- ❌ No static perimeter IPs
- ❌ No open inbound firewall ports
- ❌ No unencrypted transit

### Modern Security Practices
- ✅ WireGuard for all site-to-site connections
- ✅ OIDC for identity federation
- ✅ Zero Trust Network Access
- ✅ Secure Web Gateway with DNS filtering
- ✅ Cloud Access Security Broker
- ✅ GenAI application visibility and control
- ✅ Inline IPS with threat intelligence
- ✅ Centralized SIEM with correlation

## Deployment Requirements

### Hardware
- **RAM**: 16GB+ minimum (24GB+ recommended)
- **CPU**: 4+ cores (8+ recommended)
- **Disk**: 50GB+ free space
- **OS**: Linux host (Ubuntu 20.04+ recommended)

### Software
- Docker & Docker Compose
- Containerlab
- Ansible with network modules
- Terraform
- Cloudflare account with domain

### Cloudflare Configuration
- Cloudflare API token with appropriate permissions
- Cloudflare Account ID
- Registered domain for Cloudflare Zero Trust

## Quick Start

1. **Generate WireGuard keys**:
   ```bash
   ./generate-wg-keys.sh
   ```

2. **Configure Terraform variables**:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your credentials
   ```

3. **Deploy network infrastructure**:
   ```bash
   cd ../containerlab
   sudo clab deploy -t clab.yml
   ```

4. **Apply Ansible configuration**:
   ```bash
   cd ../ansible
   ansible-playbook -i inventory.ini site.yml
   ```

5. **Deploy identity provider**:
   ```bash
   cd ../docker/keycloak
   docker-compose up -d
   ```

6. **Deploy Cloudflare Zero Trust**:
   ```bash
   cd ../../terraform
   terraform apply
   ```

7. **Deploy firewalls and IPS**:
   ```bash
   cd ../docker/opnsense
   docker-compose up -d
   ```

8. **Deploy SIEM stack**:
   ```bash
   cd ../wazuh
   docker-compose up -d
   ```

## Access Points

After deployment, the following services will be accessible:

- **Keycloak**: http://localhost:8080 (admin/admin123)
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Wazuh Dashboard**: http://localhost:5601 (admin/admin123)
- **Wiki**: https://wiki.your-domain.com (via Cloudflare Tunnel)
- **Grafana Dashboard**: https://grafana.your-domain.com (via Cloudflare Tunnel)

## Testing Capabilities

### Identity Testing
- Test Engineering group access (full permissions)
- Test Contractor group access (limited permissions)
- Test MFA requirements
- Test OIDC token validation

### Network Testing
- Verify BGP routing between sites
- Test WireGuard overlay connectivity
- Verify PBR for application traffic
- Test SD-WAN failover

### Security Testing
- Test ZTNA access policies
- Verify DNS filtering effectiveness
- Test GenAI blocking for contractors
- Monitor Suricata IPS alerts
- Verify log correlation in SIEM

## Maintenance

### Regular Tasks
- Monitor Cloudflare tunnel connectivity
- Review Suricata IPS alerts
- Check Wazuh dashboard for security events
- Update threat intelligence rules
- Review access logs for anomalies

### Backup Recommendations
- Backup Terraform state
- Export Keycloak realm configuration
- Backup Grafana dashboards
- Archive log data from Wazuh
- Document any manual configuration changes

## Extension Possibilities

This lab can be extended with:
- Additional network sites
- More sophisticated PBR policies
- Advanced GenAI monitoring and control
- Additional SaaS application controls
- Custom Suricata rules
- Enhanced Grafana dashboards
- Integration with other security tools
- Compliance reporting

## Documentation

- **README.md**: Comprehensive deployment guide
- **PROJECT_SUMMARY.md**: This overview document
- **Inline comments**: Detailed code documentation
- **Configuration files**: Self-documenting IaC

## Support & Troubleshooting

See the main README.md for detailed troubleshooting steps and common issues.

## License

This project is provided as-is for educational and testing purposes.

---

**Generated with Devin - AI-powered DevSecOps assistant**
