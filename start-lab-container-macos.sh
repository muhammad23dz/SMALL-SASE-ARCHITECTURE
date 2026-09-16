#!/bin/bash

# Script to start the SASE Lab container environment on macOS
# With automatic Docker PATH fix

set -e

echo "========================================="
echo "SASE Lab Container Environment"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${NC}ℹ $1${NC}"
}

# Fix Docker PATH for macOS
print_info "Fixing Docker PATH for macOS..."
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

# Verify Docker is accessible
if ! command -v docker &> /dev/null; then
    print_error "Docker CLI not found even after PATH fix"
    print_info "Attempting to find Docker CLI..."
    DOCKER_PATH=$(find /Applications/Docker.app -name "docker" 2>/dev/null | head -1)
    if [ -n "$DOCKER_PATH" ]; then
        export PATH="$(dirname $DOCKER_PATH):$PATH"
        print_success "Found Docker CLI at: $DOCKER_PATH"
    else
        print_error "Docker CLI not found. Please ensure Docker Desktop is properly installed."
        exit 1
    fi
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose not found after PATH fix"
    print_info "Attempting to find docker-compose..."
    COMPOSE_PATH=$(find /Applications/Docker.app -name "docker-compose" 2>/dev/null | head -1)
    if [ -n "$COMPOSE_PATH" ]; then
        export PATH="$(dirname $COMPOSE_PATH):$PATH"
        print_success "Found docker-compose at: $COMPOSE_PATH"
    else
        print_error "docker-compose not found. Using docker compose (v2) instead"
        # Use docker compose (v2) as fallback
        alias docker-compose='docker compose'
    fi
fi

print_success "Docker CLI is now accessible"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_warning "Docker is not running. Please start Docker Desktop."
    exit 1
fi

print_success "Docker is running"

# Build and start the lab container
print_info "Building SASE Lab container environment..."
docker-compose -f docker-compose.lab.fixed.yml build

print_info "Starting SASE Lab container..."
docker-compose -f docker-compose.lab.fixed.yml up -d

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
echo "  docker-compose -f docker-compose.lab.fixed.yml down"
echo ""

print_info "To rebuild the container, run:"
echo "  docker-compose -f docker-compose.lab.fixed.yml build --no-cache"
echo ""

# Automatically enter the container
print_info "Entering the lab container..."
docker exec -it sase-lab bash
