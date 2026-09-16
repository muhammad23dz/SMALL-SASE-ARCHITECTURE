# macOS Deployment Guide via Docker Container

This guide explains how to run the complete SASE lab on macOS using a Docker container approach.

## 🎯 Why This Approach Works

Running the lab inside an Ubuntu Docker container on macOS gives you:
- ✅ Full Linux environment compatibility
- ✅ All required tools pre-installed
- ✅ Complete network simulation capabilities
- ✅ Access to macOS filesystem for your project files
- ✅ Easy cleanup and management
- ✅ No need for separate VMs

## 📋 Prerequisites for macOS

### Required Software
1. **Docker Desktop for Mac**
   - Download from https://www.docker.com/products/docker-desktop
   - Install and start Docker Desktop
   - Allocate sufficient resources (8GB+ RAM, 4+ CPUs)

2. **Project Files**
   - Ensure the sase-lab directory is in your workspace
   - Verify all files are present

## 🚀 Quick Start

### Step 1: Start the Lab Container
```bash
cd /Users/qawer7/Desktop/GRCEngineering/lambda-source/sase-lab
./start-lab-container.sh
```

This will:
- Build the Ubuntu container with all required tools
- Start the container with necessary privileges
- Automatically enter the container shell

### Step 2: Inside the Container
Once inside the container, you'll see a prompt like:
```
root@hostname:/workspace#
```

### Step 3: Set Up Secrets
```bash
# Inside the container
./setup-secrets.sh
```

### Step 4: Configure Environment Files
```bash
# Configure Keycloak
nano docker/keycloak/.env

# Configure OPNsense
nano docker/opnsense/.env

# Configure Wazuh
nano docker/wazuh/.env
```

### Step 5: Configure Vault
```bash
ansible-vault edit ansible/group_vars/all.yml
```

### Step 6: Generate WireGuard Keys
```bash
./generate-wg-keys.sh
```

### Step 7: Configure Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
cd ..
```

### Step 8: Deploy the Lab
```bash
./deploy.sh
```

Select option **1** for full deployment.

## 🛠️ Container Management

### Enter the Container (if not already inside)
```bash
docker exec -it sase-lab bash
```

### Exit the Container
```bash
exit
```

### Stop the Container
```bash
docker-compose -f docker-compose.lab.yml down
```

### Start the Container Again
```bash
docker-compose -f docker-compose.lab.yml up -d
```

### Rebuild the Container
```bash
docker-compose -f docker-compose.lab.yml build --no-cache
```

### View Container Logs
```bash
docker logs sase-lab
```

### Remove Everything
```bash
docker-compose -f docker-compose.lab.yml down -v
docker rmi sase-lab
```

## 📝 Container Configuration

### Docker Compose Lab Configuration
The `docker-compose.lab.yml` file configures:

- **Privileged Mode**: Required for network simulation
- **Host Networking**: Allows proper network functionality
- **Volume Mounts**: Shares your project files with the container
- **Docker Socket**: Enables Docker-in-Docker functionality

### Pre-installed Tools
The container includes:
- Docker & Docker Compose
- Ansible with network modules
- Terraform
- Containerlab
- WireGuard tools
- Python 3 and required libraries
- Network utilities

## 🔧 Troubleshooting

### Container Won't Start
```bash
# Check Docker Desktop is running
docker info

# Check for port conflicts
docker ps -a

# Rebuild container
docker-compose -f docker-compose.lab.yml build --no-cache
```

### Network Issues Inside Container
```bash
# Check network connectivity inside container
docker exec -it sase-lab bash
ping -c 3 8.8.8.8
ip addr show
```

### Permission Issues
```bash
# Ensure proper permissions on workspace
docker exec -it sase-lab chown -R root:root /workspace
```

### Container Out of Memory
```bash
# Increase Docker Desktop memory allocation
# Docker Desktop > Settings > Resources > Memory
# Set to 8GB+ recommended
```

## 📊 Resource Requirements

### Docker Desktop Settings
- **Memory**: 8GB minimum, 16GB recommended
- **CPUs**: 4 minimum, 8 recommended
- **Disk**: 50GB+ available

### Container Resources
The container will use:
- ~2GB RAM for base operations
- Additional RAM for Docker containers deployed inside
- CPU resources for network simulation

## 🎯 Performance Considerations

### Expected Performance
- **Container Startup**: 2-3 minutes
- **Lab Deployment**: 10-15 minutes
- **Network Simulation**: Near-native performance
- **Docker-in-Docker**: Slight overhead, but acceptable

### Optimization Tips
1. **Allocate sufficient resources** to Docker Desktop
2. **Use SSD storage** for better I/O performance
3. **Close unnecessary applications** on macOS
4. **Use wired network** if available

## 🔒 Security Considerations

### Container Security
- The container runs in privileged mode (required for network simulation)
- Docker socket is mounted (required for Docker-in-Docker)
- Project files are shared between host and container

### Best Practices
1. **Don't run untrusted code** in the container
2. **Remove container** when not in use
3. **Update base image** regularly
4. **Monitor resource usage**

## 🌐 Accessing Services from macOS

### Port Forwarding
Since the container uses host networking, services are accessible directly on macOS:

- **Keycloak**: http://localhost:8080
- **Grafana**: http://localhost:3000
- **Wazuh**: http://localhost:5601
- **Cloudflare Apps**: https://wiki.your-domain.com

### Network Configuration
The container shares the macOS network stack, so:
- Network connectivity is inherited from macOS
- DNS settings are inherited from macOS
- Firewall rules apply to container traffic

## 🔄 Workflow Integration

### Development Workflow
1. **Edit files** on macOS using your preferred IDE
2. **Deploy changes** inside the container
3. **Test results** accessible from macOS
4. **Debug** using macOS tools

### Git Workflow
```bash
# Inside the container
cd /workspace
git status
git add .
git commit -m "Your changes"
git push
```

## 📚 Additional Features

### Custom Scripts
The container includes helper scripts:
- `start-lab-container.sh` - Automated container startup
- `setup-secrets.sh` - Secrets management
- `deploy.sh` - Lab deployment
- `cleanup.sh` - Lab cleanup

### Environment Persistence
- Project files persist in your macOS filesystem
- Container state is preserved between restarts
- Docker volumes persist data for services

## 🎓 Learning Path

### Step 1: Basic Container Operations
```bash
# Start container
./start-lab-container.sh

# Explore inside
docker exec -it sase-lab bash
ls -la
which docker
which ansible
which terraform
```

### Step 2: Deploy Individual Components
```bash
# Test one component at a time
cd docker/keycloak
docker-compose up -d
# Test Keycloak at http://localhost:8080
docker-compose down
```

### Step 3: Full Deployment
```bash
# Run complete deployment
./deploy.sh
# Select option 1
```

### Step 4: Experiment and Learn
- Modify configurations
- Test different security policies
- Explore network topology
- Monitor security events

## 🆘 Common Issues and Solutions

### Issue: "Permission denied" on files
```bash
# Inside container
chmod +x *.sh
chmod -R 755 ansible/
```

### Issue: Container exits immediately
```bash
# Check container logs
docker logs sase-lab

# Rebuild container
docker-compose -f docker-compose.lab.yml build --no-cache
```

### Issue: Network simulation fails
```bash
# Ensure privileged mode is enabled
# Check docker-compose.lab.yml includes privileged: true

# Test basic networking
docker exec -it sase-lab ping -c 3 8.8.8.8
```

### Issue: Docker-in-Docker not working
```bash
# Verify docker socket mount
docker exec -it sase-lab ls -la /var/run/docker.sock

# Test docker inside container
docker exec -it sase-lab docker ps
```

## 🎉 Advantages of This Approach

### Compared to Native macOS
- ✅ Full Linux compatibility
- ✅ Complete network simulation
- ✅ All required tools available
- ✅ Consistent environment

### Compared to VM
- ✅ Faster startup time
- ✅ Lower resource overhead
- ✅ Easier file sharing
- ✅ Simpler management

### Compared to Cloud
- ✅ No cloud costs
- ✅ Local development
- ✅ Faster iteration
- ✅ Offline capability

## 📈 Performance Metrics

### Startup Times
- **Container Build**: 5-10 minutes (first time)
- **Container Start**: 30-60 seconds
- **Lab Deployment**: 10-15 minutes

### Resource Usage
- **Idle Container**: ~500MB RAM
- **During Deployment**: 4-8GB RAM
- **Running Lab**: 6-12GB RAM

## 🔮 Future Enhancements

### Potential Improvements
- Add VS Code remote development support
- Create multi-container orchestration
- Add automated testing suite
- Implement backup/restore functionality
- Add performance monitoring

---

## 🎯 Quick Reference

### Essential Commands
```bash
# Start lab
./start-lab-container.sh

# Enter container
docker exec -it sase-lab bash

# Stop lab
docker-compose -f docker-compose.lab.yml down

# View logs
docker logs sase-lab

# Clean everything
docker-compose -f docker-compose.lab.yml down -v
docker rmi sase-lab
```

### File Locations
- **Project Files**: `/workspace` (inside container)
- **Docker Socket**: `/var/run/docker.sock`
- **Cache**: `/workspace/.cache`

### Service Access
- **Keycloak**: http://localhost:8080
- **Grafana**: http://localhost:3000
- **Wazuh**: http://localhost:5601

This Docker container approach gives you the best of both worlds: macOS convenience with full Linux compatibility for the SASE lab!
