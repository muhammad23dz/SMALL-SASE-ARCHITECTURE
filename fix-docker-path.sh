#!/bin/bash

# Quick fix for Docker PATH issue on macOS

echo "=== Fixing Docker PATH for macOS ==="

# Add Docker CLI to PATH for current session
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

# Test Docker commands
echo "Testing Docker CLI..."
docker --version
docker-compose --version

echo ""
echo "✓ Docker CLI is now accessible in this session"
echo ""
echo "To make this permanent, run:"
echo "  echo 'export PATH=\"/Applications/Docker.app/Contents/Resources/bin:\$PATH\"' >> ~/.zshrc"
echo "  source ~/.zshrc"
echo ""
echo "Now you can run:"
echo "  ./start-lab-container.sh"
