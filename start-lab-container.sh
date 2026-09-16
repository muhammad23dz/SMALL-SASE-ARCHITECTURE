#!/bin/bash

# Script to start the SASE Lab container environment on macOS

set -e

echo "========================================="
echo "SASE Lab Container Environment"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${NC}ℹ $1${NC}"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_warning "Docker is not running. Please start Docker Desktop."
    exit 1
fi

print_success "Docker is running"

# Build and start the lab container
print_info "Building SASE Lab container environment..."
docker-compose -f docker-compose.lab.yml build

print_info "Starting SASE Lab container..."
docker-compose -f docker-compose.lab.yml up -d

print_success "SASE Lab container started successfully!"
echo ""

print_info "To enter the lab container, run:"
echo "  docker exec -it sase-lab bash"
echo ""

print_info "Once inside the container, you can:"
echo "  1. Navigate to workspace: cd /workspace"
echo "  2. Run secrets setup: ./setup-secrets.sh"
echo "  3. Configure environment files"
echo "  4. Deploy the lab: ./deploy.sh"
echo ""

print_info "To stop the lab container, run:"
echo "  docker-compose -f docker-compose.lab.yml down"
echo ""

print_info "To rebuild the container, run:"
echo "  docker-compose -f docker-compose.lab.yml build --no-cache"
echo ""

# Automatically enter the container
print_info "Entering the lab container..."
docker exec -it sase-lab bash
