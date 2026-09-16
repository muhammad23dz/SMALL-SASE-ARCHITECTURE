#!/bin/bash

# SASE Lab Cleanup Script
# This script destroys the complete SASE lab environment

set -e

echo "========================================="
echo "SASE-as-Code Lab Cleanup Script"
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

# Change to script directory
cd "$(dirname "$0")"

# Confirm cleanup
print_warning "This will destroy the entire SASE lab environment."
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    print_info "Cleanup cancelled."
    exit 0
fi

# Destroy Terraform resources
print_info "Destroying Terraform resources..."
if [ -d "terraform" ] && [ -f "terraform/terraform.tfvars" ]; then
    cd terraform
    terraform destroy -auto-approve
    print_success "Terraform resources destroyed"
    cd ..
else
    print_warning "Terraform resources not found or not configured. Skipping."
fi
echo ""

# Stop Docker services
print_info "Stopping Docker services..."

# Stop Keycloak
if [ -f "docker/keycloak/docker-compose.yml" ]; then
    cd docker/keycloak
    docker-compose down
    print_success "Keycloak stopped"
    cd ../..
else
    print_warning "Keycloak not found. Skipping."
fi

# Stop OPNsense
if [ -f "docker/opnsense/docker-compose.yml" ]; then
    cd docker/opnsense
    docker-compose down
    print_success "OPNsense stopped"
    cd ../..
else
    print_warning "OPNsense not found. Skipping."
fi

# Stop Wazuh
if [ -f "docker/wazuh/docker-compose.yml" ]; then
    cd docker/wazuh
    docker-compose down
    print_success "Wazuh stopped"
    cd ../..
else
    print_warning "Wazuh not found. Skipping."
fi
echo ""

# Destroy Containerlab lab
print_info "Destroying Containerlab lab..."
if [ -f "containerlab/clab.yml" ]; then
    cd containerlab
    sudo clab destroy -t clab.yml
    print_success "Containerlab lab destroyed"
    cd ..
else
    print_warning "Containerlab configuration not found. Skipping."
fi
echo ""

# Remove Docker volumes
print_info "Removing Docker volumes..."
docker volume prune -f
print_success "Docker volumes pruned"
echo ""

# Remove WireGuard keys
print_info "Removing WireGuard keys..."
rm -f ansible/roles/vyos/vars/*_private.key ansible/roles/vyos/vars/*_public.key
print_success "WireGuard keys removed"
echo ""

# Remove sensitive files
print_info "Removing sensitive files..."
rm -f terraform/terraform.tfvars terraform/terraform.tfstate terraform/terraform.tfstate.backup
print_success "Sensitive files removed"
echo ""

# Remove Terraform directory
print_info "Removing Terraform directory..."
rm -rf terraform/.terraform
print_success "Terraform directory cleaned"
echo ""

print_success "Cleanup completed successfully!"
echo ""
print_info "Note: This does not remove the Terraform example file (terraform.tfvars.example)."
print_info "You can reconfigure and redeploy the lab by running ./deploy.sh"
