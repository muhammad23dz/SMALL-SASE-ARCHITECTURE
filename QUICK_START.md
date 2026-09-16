# SASE Lab Quick Start Guide

## Prerequisites Check

Before starting, ensure you have:
- Linux host with 16GB+ RAM
- Docker, Docker Compose, Containerlab, Ansible, Terraform installed
- Cloudflare account with API token and domain

## 5-Minute Quick Deployment

```bash
# 1. Navigate to the project directory
cd sase-lab

# 2. Generate WireGuard keys
./generate-wg-keys.sh

# 3. Configure Terraform credentials
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Cloudflare credentials
nano terraform.tfvars

# 4. Run automated deployment
cd ..
./deploy.sh
# Select option 1 for full deployment
```

## Manual Deployment Steps

If you prefer manual control over each phase:

### Phase 1: Network Infrastructure (5 minutes)
```bash
cd containerlab
sudo clab deploy -t clab.yml
cd ../ansible
ansible-playbook -i inventory.ini site.yml
```

### Phase 2: Identity Provider (3 minutes)
```bash
cd ../docker/keycloak
docker-compose up -d
# Import realm-export.json via Keycloak UI at http://localhost:8080
```

### Phase 3: Cloudflare Zero Trust (2 minutes)
```bash
cd ../../terraform
terraform init
terraform apply
```

### Phase 4: Firewalls and IPS (3 minutes)
```bash
cd ../docker/opnsense
docker-compose up -d
```

### Phase 5: SIEM Stack (4 minutes)
```bash
cd ../wazuh
docker-compose up -d
```

## Access Your Lab

After deployment, access these services:

- **Keycloak**: http://localhost:8080 (admin/admin123)
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Wazuh Dashboard**: http://localhost:5601 (admin/admin123)
- **Wiki**: https://wiki.your-domain.com (via Cloudflare Tunnel)
- **Grafana Dashboard**: https://grafana.your-domain.com (via Cloudflare Tunnel)

## Test Your Setup

### Test Identity Provider
1. Access Keycloak at http://localhost:8080
2. Login with admin/admin123
3. Navigate to the sase-lab realm
4. Verify Engineering and Contractors groups exist
5. Test user login with eng-admin/Engineering123!

### Test Network Connectivity
```bash
# Test BGP routes
docker exec clab-sase-lab-hq-vyos vtysh -c "show ip bgp summary"

# Test WireGuard connectivity
docker exec clab-sase-lab-hq-vyos ping -c 3 10.100.0.2
```

### Test Security Components
1. Access Grafana dashboard at http://localhost:3000
2. Verify SASE Security Correlation Dashboard is populated
3. Check Wazuh dashboard at http://localhost:5601
4. Verify Cloudflare Zero Trust tunnel status

## Cleanup

To destroy the entire lab:
```bash
./cleanup.sh
```

## Troubleshooting

### Containerlab won't start
```bash
sudo clab destroy -t containerlab/clab.yml
sudo clab deploy -t containerlab/clab.yml
```

### Ansible connection fails
```bash
# Wait for containers to fully start (2-3 minutes)
docker ps
ansible -i ansible/inventory.ini vyos_routers -m ping
```

### Terraform apply fails
```bash
# Check Cloudflare credentials in terraform.tfvars
# Verify Cloudflare API token has correct permissions
terraform plan -refresh-only
```

### Docker services won't start
```bash
# Check for port conflicts
netstat -tulpn | grep LISTEN
# Restart Docker
sudo systemctl restart docker
```

## Support

For detailed information, see:
- README.md - Comprehensive deployment guide
- PROJECT_SUMMARY.md - Project overview and architecture
- Individual configuration files - Inline documentation

## Key Features Demonstrated

✅ **Zero Trust Architecture**: Identity-based access control
✅ **No Inbound Ports**: All applications via Cloudflare Tunnels
✅ **Modern Cryptography**: WireGuard for site-to-site connections
✅ **IaC Automation**: 100% infrastructure as code
✅ **Security Visibility**: Unified Grafana dashboard
✅ **GenAI Controls**: AI application monitoring and blocking
✅ **SD-WAN Overlay**: WireGuard mesh network
✅ **IPS Protection**: Suricata inline threat detection
✅ **SIEM Integration**: Wazuh centralized logging
✅ **Multi-site Network**: HQ, Branch, Remote Worker simulation

## Next Steps

1. **Customize Policies**: Modify Terraform policies for your requirements
2. **Add Applications**: Extend Cloudflare tunnel configuration
3. **Create Dashboards**: Customize Grafana dashboards
4. **Add Users**: Configure additional Keycloak users
5. **Extend Network**: Add more sites to the Containerlab topology
6. **Monitor Events**: Set up alerts in Wazuh and Grafana
7. **Test Failover**: Test SD-WAN failover scenarios
8. **Audit Configuration**: Review security policies regularly

## Production Considerations

This is a lab environment. For production deployment:
- Change all default passwords
- Use production-grade encryption keys
- Implement proper backup strategy
- Configure high availability
- Add comprehensive monitoring
- Implement disaster recovery
- Conduct security audits
- Compliance verification
- Performance optimization
- Capacity planning

---

**Need Help?** Check the comprehensive README.md for detailed troubleshooting and configuration options.
