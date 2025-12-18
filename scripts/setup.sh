#!/bin/bash

################################################################################
# Docker Server Setup - Main Orchestration Script
# 
# This script automates the complete setup of a fresh Ubuntu server for
# Docker container hosting. It runs all necessary setup steps in order.
#
# Usage: sudo ./setup.sh
# Supported: Ubuntu 20.04, 22.04, 24.04 LTS
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

################################################################################
# Prerequisite Checks
################################################################################

log_info "Docker Server Setup - Checking prerequisites..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check Ubuntu version
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "This script is designed for Ubuntu. Current OS: $ID"
        exit 1
    fi
    if [[ ! "$VERSION_ID" =~ ^(20\.04|22\.04|24\.04)$ ]]; then
        log_warning "This script was tested on Ubuntu 20.04, 22.04, 24.04. Current version: $VERSION_ID"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    log_success "Detected Ubuntu $VERSION_ID"
else
    log_error "Cannot determine Ubuntu version"
    exit 1
fi

# Check for internet connectivity
if ! ping -q -c 1 8.8.8.8 &> /dev/null; then
    log_warning "No internet connectivity detected. Setup may fail."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    log_success "Internet connectivity verified"
fi

# Check available disk space (at least 5GB)
AVAIL_SPACE=$(df / | awk 'NR==2 {print $4}')
if [[ $AVAIL_SPACE -lt 5242880 ]]; then
    log_warning "Available disk space is low ($(numfmt --to=iec $AVAIL_SPACE 2>/dev/null || echo "$AVAIL_SPACE KB")). Recommended: 20GB+"
else
    log_success "Disk space check passed"
fi

################################################################################
# User Confirmation
################################################################################

echo
log_info "This script will:"
echo "  1. Update system packages"
echo "  2. Install Docker Engine, Docker CLI, and containerd"
echo "  3. Configure Docker daemon"
echo "  4. Create docker group and configure user access"
echo "  5. Setup network configuration"
echo "  6. Verify installation"
echo
read -p "Proceed with Docker setup? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Setup cancelled"
    exit 0
fi

################################################################################
# System Update
################################################################################

log_info "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq
log_success "System packages updated"

################################################################################
# Install Docker
################################################################################

log_info "Installing Docker Engine..."

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    log_warning "Docker is already installed (version: $(docker --version))"
    read -p "Reinstall Docker? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping Docker installation"
        SKIP_DOCKER_INSTALL=true
    else
        SKIP_DOCKER_INSTALL=false
    fi
else
    SKIP_DOCKER_INSTALL=false
fi

if [[ "$SKIP_DOCKER_INSTALL" != "true" ]]; then
    # Install prerequisites
    apt-get install -y -qq apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list
    apt-get update -qq
    
    # Install Docker packages
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_success "Docker Engine installed: $(docker --version)"
fi

################################################################################
# Configure Docker Daemon
################################################################################

log_info "Configuring Docker daemon..."

# Ensure /etc/docker directory exists
mkdir -p /etc/docker

# Create docker daemon configuration
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "10"
  },
  "dns": ["8.8.8.8", "8.8.4.4"],
  "userland-proxy": true,
  "icc": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "storage-driver": "overlay2"
}
EOF

log_success "Docker daemon configured"

################################################################################
# Enable Docker Service
################################################################################

log_info "Enabling Docker service on boot..."
systemctl daemon-reload
systemctl enable docker
systemctl restart docker
log_success "Docker service enabled and restarted"

################################################################################
# Setup Docker Group and Users
################################################################################

log_info "Setting up docker group and user access..."

# Create docker group if it doesn't exist
if ! getent group docker > /dev/null; then
    groupadd docker
    log_success "Docker group created"
else
    log_info "Docker group already exists"
fi

# Fix socket permissions
chown root:docker /var/run/docker.sock
chmod 660 /var/run/docker.sock

# Ask if user wants to add a user to docker group
read -p "Add current user to docker group? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -z "${SUDO_USER:-}" ]]; then
        read -p "Enter username to add to docker group: " -r USERNAME
    else
        USERNAME="$SUDO_USER"
    fi
    
    if id "$USERNAME" &>/dev/null 2>&1; then
        usermod -aG docker "$USERNAME"
        log_success "User '$USERNAME' added to docker group"
        echo
        echo -e "${YELLOW}Note:${NC} User must logout and login again for group changes to take effect."
        echo "Or run: newgrp docker"
    else
        log_error "User '$USERNAME' does not exist"
    fi
fi

################################################################################
# System Optimization
################################################################################

log_info "Applying system optimization..."

# Set kernel parameters for Docker
sysctl -w vm.max_map_count=262144 > /dev/null
sysctl -w fs.file-max=2097152 > /dev/null
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# Make kernel parameters persistent
cat >> /etc/sysctl.conf << EOF
# Docker optimizations
vm.max_map_count=262144
fs.file-max=2097152
net.ipv4.ip_forward=1
EOF

sysctl -p > /dev/null 2>&1 || true

log_success "System optimization applied"

################################################################################
# Network Configuration
################################################################################

log_info "Configuring Docker networking..."

# Ensure IP forwarding is enabled for Docker networks
echo 'net.ipv4.ip_forward=1' | tee -a /etc/sysctl.conf > /dev/null
echo 'net.ipv6.conf.all.forwarding=1' | tee -a /etc/sysctl.conf > /dev/null
sysctl -p > /dev/null 2>&1 || true

log_success "Docker networking configured"

################################################################################
# Verification
################################################################################

log_info "Verifying Docker installation..."
echo

# Docker version
log_info "Docker Version:"
docker --version

# Docker daemon status
if systemctl is-active --quiet docker; then
    log_success "Docker daemon is running"
else
    log_error "Docker daemon is not running"
    exit 1
fi

# Test Docker by running hello-world
log_info "Running hello-world test..."
if docker run --rm hello-world > /dev/null 2>&1; then
    log_success "hello-world test passed"
else
    log_warning "hello-world test failed. This might be expected if Docker is newly installed."
fi

# Check docker group
if getent group docker > /dev/null; then
    log_success "Docker group exists"
    DOCKER_USERS=$(getent group docker | cut -d: -f4)
    if [[ -n "$DOCKER_USERS" ]]; then
        log_info "Docker group members: $DOCKER_USERS"
    fi
fi

# Docker info
log_info "Docker info:"
docker info --format 'Server: {{.ServerVersion}}\nStorage: {{.Driver}}\nCgroup: {{.CgroupDriver}}\nOS: {{.OperatingSystem}}'

echo
log_success "✓ Docker Server Setup Complete!"
echo
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Review security settings: see SECURITY.md"
echo "  2. Configure networking: see NETWORKING.md"
echo "  3. Run container tests: docker run -it alpine /bin/sh"
echo "  4. Setup Docker Compose if needed: see GUIDE.md"
echo
echo -e "${YELLOW}Important:${NC} If you added your user to the docker group, logout and login for changes to take effect."
echo
