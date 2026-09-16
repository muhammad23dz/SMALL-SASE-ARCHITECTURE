#!/bin/bash

# SASE Lab Deployment Script
# This script automates the deployment of the complete SASE lab environment

set -e

echo "========================================="
echo "SASE-as-Code Lab Deployment Script"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${NC}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is installed"

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is installed"

    # Check Containerlab
    if ! command -v clab &> /dev/null; then
        print_error "Containerlab is not installed"
        exit 1
    fi
    print_success "Containerlab is installed"

    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed"
        exit 1
    fi
    print_success "Ansible is installed"

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    print_success "Terraform is installed"

    # Check Vault password file
    if [ ! -f ".vault_password" ]; then
        print_warning "Vault password file not found. Running setup script..."
        ./setup-secrets.sh
    fi
    print_success "Vault configuration found"

    echo ""
}

# Generate WireGuard keys
generate_wireguard_keys() {
    print_info "Generating WireGuard keys..."
    if [ -f "ansible/roles/frr/vars/hq_private.key" ]; then
        print_warning "WireGuard keys already exist. Skipping generation."
    else
        ./generate-wg-keys.sh
        print_success "WireGuard keys generated"
    fi
    echo ""
}

# Check Terraform configuration
check_terraform_config() {
    print_info "Checking Terraform configuration..."
    if [ ! -f "terraform/terraform.tfvars" ]; then
        print_error "terraform.tfvars not found. Please copy terraform.tfvars.example and configure it."
        exit 1
    fi
    print_success "Terraform configuration found"
    echo ""
}

# Deploy Phase 1: Network Infrastructure
deploy_phase1() {
    print_info "Deploying Phase 1: Network Infrastructure..."

    print_info "Building custom Alpine image for firewalls..."
    docker build -t custom-alpine-fw - <<EOF
FROM alpine:latest
RUN apk add --no-cache python3 iproute2 iptables
EOF
    print_success "Custom Alpine image built"

    cd containerlab
    clab deploy --reconfigure -t clab.yml
    print_success "Containerlab topology deployed"
    cd ..

    print_info "Applying Ansible configuration..."
    cd ansible
    ansible-playbook -i inventory.ini site.yml --vault-password-file ../.vault_password
    print_success "Ansible configuration applied"
    cd ..
    echo ""
}


# Deploy Phase 2: Identity Provider
deploy_phase2() {
    print_info "Deploying Phase 2: Identity Provider..."
    cd docker/keycloak
    if [ ! -f .env ]; then
        print_warning ".env file not found. Copying from .env.example"
        cp .env.example .env
        print_warning "Please update .env with your credentials before proceeding"
        read -p "Press Enter to continue after updating .env file"
    fi
    docker-compose up -d --build
    print_success "Keycloak deployed"
    cd ../..
    echo ""
}

# Deploy Phase 3: Cloudflare Zero Trust
deploy_phase3() {
    print_info "Deploying Phase 3: Cloudflare Zero Trust..."
    cd terraform
    terraform init
    terraform apply -auto-approve
    print_success "Cloudflare Zero Trust deployed"
    cd ..
    echo ""
}

# Deploy Phase 4: Firewalls and IPS
deploy_phase4() {
    print_info "Deploying Phase 4: Firewalls and IPS..."
    cd docker/opnsense
    if [ ! -f .env ]; then
        print_warning ".env file not found. Copying from .env.example"
        cp .env.example .env
        print_warning "Please update .env with your credentials before proceeding"
        read -p "Press Enter to continue after updating .env file"
    fi
    docker-compose up -d --build
    print_success "OPNsense and Suricata deployed"
    cd ../..
    echo ""
}

# Deploy Phase 5: SIEM Stack
deploy_phase5() {
    print_info "Deploying Phase 5: SIEM Stack..."
    cd docker/wazuh
    if [ ! -f .env ]; then
        print_warning ".env file not found. Copying from .env.example"
        cp .env.example .env
        print_warning "Please update .env with your credentials before proceeding"
        read -p "Press Enter to continue after updating .env file"
    fi
    docker-compose up -d --build
    print_success "Wazuh and Grafana deployed"
    cd ../..
    echo ""
}

# Enable log integration
enable_log_integration() {
    print_info "Enabling log integration..."
    cd terraform
    sed -i 's/enable_logpush = false/enable_logpush = true/' terraform.tfvars
    terraform apply -auto-approve
    print_success "Log integration enabled"
    cd ..
    echo ""
}

# Display access information
display_access_info() {
    print_info "Deployment completed successfully!"
    echo ""
    echo "========================================="
    echo "Access Information"
    echo "========================================="
    echo "Keycloak: http://localhost:8080 (admin/admin123)"
    echo "Grafana: http://localhost:3000 (admin/admin123)"
    echo "Wazuh Dashboard: http://localhost:5601 (admin/admin123)"
    echo ""
    echo "Cloudflare Applications:"
    echo "Wiki: https://wiki.$(grep cloudflare_domain terraform/terraform.tfvars | cut -d'"' -f2)"
    echo "Grafana: https://grafana.$(grep cloudflare_domain terraform/terraform.tfvars | cut -d'"' -f2)"
    echo ""
    echo "========================================="
    echo "Next Steps"
    echo "========================================="
    echo "1. Import Keycloak realm from docker/keycloak/realm-export.json"
    echo "2. Configure Cloudflared on application servers"
    echo "3. Test access to applications via Cloudflare Tunnel"
    echo "4. Monitor security events in Grafana dashboard"
    echo ""
}

# Main deployment function
main() {
    # Change to script directory
    cd "$(dirname "$0")"

    # Check prerequisites
    check_prerequisites

    # Generate WireGuard keys
    generate_wireguard_keys

    # Check Terraform configuration
    check_terraform_config

    # Ask user which phases to deploy
    echo "Select deployment phases:"
    echo "1) Full deployment (all phases)"
    echo "2) Phase 1 only (Network Infrastructure)"
    echo "3) Phase 2 only (Identity Provider)"
    echo "4) Phase 3 only (Cloudflare Zero Trust)"
    echo "5) Phase 4 only (Firewalls and IPS)"
    echo "6) Phase 5 only (SIEM Stack)"
    echo "7) Custom deployment"
    read -p "Enter your choice (1-7): " choice

    case $choice in
        1)
            deploy_phase1
            deploy_phase2
            deploy_phase3
            deploy_phase4
            deploy_phase5
            enable_log_integration
            display_access_info
            ;;
        2)
            deploy_phase1
            ;;
        3)
            deploy_phase2
            ;;
        4)
            deploy_phase3
            ;;
        5)
            deploy_phase4
            ;;
        6)
            deploy_phase5
            ;;
        7)
            echo "Enter phases to deploy (comma-separated, e.g., 1,2,3):"
            read -p "Phases: " phases
            for phase in $(echo $phases | tr "," " "); do
                case $phase in
                    1) deploy_phase1 ;;
                    2) deploy_phase2 ;;
                    3) deploy_phase3 ;;
                    4) deploy_phase4 ;;
                    5) deploy_phase5 ;;
                    *) print_error "Invalid phase: $phase" ;;
                esac
            done
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Run main function
main
