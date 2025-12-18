#!/bin/bash

################################################################################
# Docker Server Verification Script
#
# Verifies Docker installation and configuration
# Usage: ./scripts/verify.sh
################################################################################

set -o pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo "========================================"
echo "Docker Server Verification"
echo "========================================"
echo

# 1. Check if Docker is installed
info "Checking Docker installation..."
if command -v docker &> /dev/null; then
    pass "Docker is installed"
    VERSION=$(docker --version)
    info "Version: $VERSION"
else
    fail "Docker is not installed"
    exit 1
fi

echo

# 2. Check Docker daemon status
info "Checking Docker daemon status..."
if systemctl is-active --quiet docker; then
    pass "Docker daemon is running"
else
    fail "Docker daemon is not running"
    fail "Start with: sudo systemctl start docker"
    exit 1
fi

echo

# 3. Check socket permissions
info "Checking Docker socket permissions..."
if [[ -S /var/run/docker.sock ]]; then
    pass "Docker socket exists"
    
    # Check ownership
    SOCKET_OWNER=$(stat -c %U:%G /var/run/docker.sock 2>/dev/null || stat -f %Su:%Sg /var/run/docker.sock 2>/dev/null)
    SOCKET_PERMS=$(stat -c %a /var/run/docker.sock 2>/dev/null || stat -f %OLp /var/run/docker.sock 2>/dev/null | cut -c 3-)
    
    info "Socket owner: $SOCKET_OWNER"
    info "Socket permissions: $SOCKET_PERMS"
    
    if [[ $SOCKET_PERMS == 660 ]]; then
        pass "Socket permissions are correct (660)"
    else
        warn "Socket permissions may be incorrect (found: $SOCKET_PERMS, expected: 660)"
    fi
else
    fail "Docker socket not found at /var/run/docker.sock"
fi

echo

# 4. Check docker group
info "Checking docker group..."
if getent group docker > /dev/null; then
    pass "Docker group exists"
    
    DOCKER_USERS=$(getent group docker | cut -d: -f4)
    if [[ -z "$DOCKER_USERS" ]]; then
        warn "Docker group exists but has no members"
    else
        pass "Docker group members: $DOCKER_USERS"
    fi
else
    fail "Docker group does not exist"
fi

echo

# 5. Check current user permissions
info "Checking current user Docker access..."
if groups $USER 2>/dev/null | grep -q docker; then
    pass "Current user is in docker group"
else
    warn "Current user is not in docker group"
    warn "Add with: sudo usermod -aG docker $USER"
fi

echo

# 6. Test basic Docker command
info "Testing basic Docker command..."
if docker ps > /dev/null 2>&1; then
    pass "Can run 'docker ps' without sudo"
else
    warn "Cannot run 'docker ps' without sudo"
    warn "Trying with sudo..."
    if sudo docker ps > /dev/null 2>&1; then
        pass "Can run 'docker ps' with sudo"
    else
        fail "Cannot run 'docker ps' even with sudo"
    fi
fi

echo

# 7. Check IP forwarding
info "Checking IP forwarding configuration..."
IP_FORWARD=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
if [[ "$IP_FORWARD" == "1" ]]; then
    pass "IPv4 forwarding is enabled"
else
    warn "IPv4 forwarding is disabled"
    warn "Enable with: sudo sysctl -w net.ipv4.ip_forward=1"
fi

echo

# 8. Check Docker daemon configuration
info "Checking Docker daemon configuration..."
if [[ -f /etc/docker/daemon.json ]]; then
    pass "Daemon configuration file exists"
    
    # Validate JSON
    if jq . /etc/docker/daemon.json > /dev/null 2>&1; then
        pass "daemon.json is valid JSON"
        
        # Show some settings
        LOG_DRIVER=$(jq -r '."log-driver" // "json-file"' /etc/docker/daemon.json)
        STORAGE_DRIVER=$(jq -r '."storage-driver" // "auto"' /etc/docker/daemon.json)
        info "Log driver: $LOG_DRIVER"
        info "Storage driver: $STORAGE_DRIVER"
    else
        fail "daemon.json has invalid JSON"
    fi
else
    warn "daemon.json not found (using defaults)"
fi

echo

# 9. Check Docker networks
info "Checking Docker networks..."
NETWORKS=$(docker network ls --quiet 2>/dev/null | wc -l)
if [[ $NETWORKS -gt 0 ]]; then
    pass "Docker networks available ($NETWORKS found)"
    docker network ls --format 'table {{.Name}}\t{{.Driver}}' 2>/dev/null
else
    fail "No Docker networks found"
fi

echo

# 10. Check storage driver
info "Checking storage driver..."
STORAGE=$(docker info 2>/dev/null | grep 'Storage Driver' | cut -d: -f2 | xargs)
if [[ -n "$STORAGE" ]]; then
    pass "Storage driver: $STORAGE"
else
    fail "Could not determine storage driver"
fi

echo

# 11. Check cgroup driver
info "Checking cgroup driver..."
CGROUP=$(docker info 2>/dev/null | grep 'Cgroup Driver' | cut -d: -f2 | xargs)
if [[ -n "$CGROUP" ]]; then
    pass "Cgroup driver: $CGROUP"
else
    warn "Could not determine cgroup driver"
fi

echo

# 12. Test hello-world container
info "Testing hello-world container..."
if docker run --rm hello-world > /dev/null 2>&1; then
    pass "hello-world container test passed"
else
    warn "hello-world container test failed"
    warn "This may be normal on fresh installations"
    warn "Try: docker pull hello-world && docker run --rm hello-world"
fi

echo

# 13. Check disk usage
info "Checking Docker disk usage..."
if command -v docker &> /dev/null; then
    USAGE=$(docker system df 2>/dev/null | tail -1 | awk '{print $4, $5}')
    if [[ -n "$USAGE" ]]; then
        pass "Docker disk usage: $USAGE"
    fi
fi

echo

# 14. Check Docker info
info "Docker information:"
docker info --format 'Operating System: {{.OperatingSystem}}\nKernel Version: {{.KernelVersion}}\nTotal Memory: {{.MemTotal}}' 2>/dev/null || warn "Could not retrieve Docker info"

echo
echo "========================================"
echo "Verification Summary"
echo "========================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
fi
if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $FAILED${NC}"
fi
echo

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    if [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}✓ No warnings!${NC}"
    fi
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review above.${NC}"
    exit 1
fi
