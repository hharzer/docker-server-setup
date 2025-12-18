# Docker Server Setup Guide

Comprehensive step-by-step guide for preparing an Ubuntu server to host Docker containers.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Pre-Installation Checks](#pre-installation-checks)
3. [Installation Steps](#installation-steps)
4. [User and Group Management](#user-and-group-management)
5. [Network Configuration](#network-configuration)
6. [Docker Daemon Configuration](#docker-daemon-configuration)
7. [Verification Steps](#verification-steps)
8. [Post-Installation Configuration](#post-installation-configuration)
9. [Troubleshooting](#troubleshooting)

---

## System Requirements

### Operating System
- **Ubuntu 20.04 LTS**, **22.04 LTS**, or **24.04 LTS**
- Fresh installation recommended
- Root or sudo access required

### Hardware
- **CPU**: 2+ cores recommended
- **RAM**: 2GB minimum, 4GB+ recommended
- **Disk**: 20GB+ available space
- **Network**: Internet connectivity for package downloads

### Kernel
- Kernel 4.15 or later (usually pre-installed)
- Check: `uname -r`

### System Capabilities
Verify cgroup v2 support:
```bash
grep cgroup /proc/filesystems
ls -l /sys/fs/cgroup/
```

---

## Pre-Installation Checks

### 1. Verify Ubuntu Version

```bash
lsb_release -a
# or
cat /etc/os-release
```

Expected output for Ubuntu 22.04:
```
DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=22.04
DISTRIB_CODENAME=jammy
```

### 2. Check Internet Connectivity

```bash
ping -c 4 google.com
```

### 3. Verify Disk Space

```bash
df -h /
# Ensure at least 20GB available
```

### 4. Check for Existing Docker Installation

```bash
which docker
docker --version

# Remove if necessary (see cleanup section)
```

### 5. Verify Sudo Access

```bash
sudo echo "Sudo access verified"
```

---

## Installation Steps

### Method A: Automated Setup (Recommended)

**Simplest approach - runs all steps automatically:**

```bash
# Clone repository
git clone https://github.com/yourusername/docker-server-setup.git
cd docker-server-setup

# Make scripts executable
chmod +x scripts/*.sh

# Run setup
sudo ./scripts/setup.sh
```

The script will:
- Update system packages
- Install Docker Engine and dependencies
- Configure Docker daemon
- Setup docker group
- Apply system optimizations
- Verify installation

### Method B: Manual Step-by-Step Installation

#### Step 1: Update System Packages

```bash
sudo apt update
sudo apt upgrade -y
```

#### Step 2: Install Prerequisites

These packages enable HTTPS downloads and GPG verification:

```bash
sudo apt install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common \
  gnupg \
  lsb-release
```

**What each package does:**
- `apt-transport-https`: Allows apt to retrieve packages over HTTPS
- `ca-certificates`: Contains root certificates for SSL/TLS verification
- `curl`: HTTP client for downloading files
- `software-properties-common`: Manages software repositories
- `gnupg`: For GPG key verification
- `lsb-release`: Identifies Ubuntu release information

#### Step 3: Add Docker's GPG Key

Download and verify Docker's GPG key:

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```

Verify the key was added:

```bash
ls -lh /usr/share/keyrings/docker-archive-keyring.gpg
```

#### Step 4: Add Docker Repository

```bash
echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

**Breakdown:**
- `arch=$(dpkg --print-architecture)`: Detects CPU architecture (amd64, arm64, etc.)
- `signed-by=...`: Uses GPG key for package verification
- `$(lsb_release -cs)`: Gets Ubuntu codename (focal, jammy, noble, etc.)
- `stable`: Uses stable Docker releases (not test/nightly)

#### Step 5: Update Package Index

```bash
sudo apt update
```

#### Step 6: Install Docker Packages

```bash
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

**Package Details:**
- `docker-ce`: Docker Community Edition daemon
- `docker-ce-cli`: Docker command-line interface
- `containerd.io`: Container runtime
- `docker-buildx-plugin`: Extended build capabilities
- `docker-compose-plugin`: Docker Compose v2

#### Step 7: Verify Installation

```bash
docker --version
```

Expected output: `Docker version 27.x.x, build xxxxx`

#### Step 8: Start Docker Service

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

Verify it's running:

```bash
sudo systemctl status docker
```

---

## User and Group Management

### Understanding Docker Group Privileges

**Important Security Note:** The docker group grants effectively root-equivalent privileges. Members can:
- Mount host filesystems into containers
- Run privileged containers
- Access the entire host system

**Only add trusted users to the docker group.**

### Setting Up Docker Group Access

#### Step 1: Ensure Docker Group Exists

Docker installation creates the group automatically:

```bash
getent group docker
# Output: docker:x:999:
```

If missing, create it:

```bash
sudo groupadd -r docker
```

#### Step 2: Verify Docker Socket Permissions

```bash
ls -l /var/run/docker.sock
# Output: srw-rw---- 1 root docker 0 Dec 18 10:15 /var/run/docker.sock
```

Fix permissions if needed:

```bash
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock
```

#### Step 3: Add User to Docker Group

```bash
# Replace 'username' with actual username
sudo usermod -aG docker username
```

Verify membership:

```bash
getent group docker
# Output: docker:x:999:username
```

#### Step 4: Apply Group Changes to Current Session

**Option A: Start New Group Session (temporary for current session)**

```bash
newgrp docker
```

Verify:

```bash
groups
# Output: username docker
```

**Option B: Logout and Login (permanent)**

```bash
exit
# Login again
```

#### Step 5: Test Non-Root Docker Access

```bash
# Should work without sudo
docker run hello-world

# If error, run newgrp or logout/login
```

### Managing Multiple Users

Add multiple users to docker group:

```bash
for user in alice bob charlie; do
  sudo usermod -aG docker $user
done
```

List all docker group members:

```bash
getent group docker | cut -d: -f4
```

Remove user from docker group:

```bash
sudo deluser username docker
```

### Alternative: Sudo Without Password

If you prefer not to add users to docker group, configure sudo:

```bash
sudo visudo -f /etc/sudoers.d/docker
```

Add the line:

```
username ALL=(root) NOPASSWD: /usr/bin/docker
```

Then use:

```bash
sudo docker run hello-world
```

---

## Network Configuration

### Docker Bridge Network (Default)

Docker creates a default bridge network for container-to-container communication:

```bash
# View networks
docker network ls

# Inspect bridge network
docker network inspect bridge
```

### Network Requirements

1. **IP Forwarding**: Enable so containers can communicate with host and external networks

```bash
# Check current setting
sysctl net.ipv4.ip_forward

# Enable (temporary)
sudo sysctl -w net.ipv4.ip_forward=1

# Make persistent
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

2. **Firewall Configuration**

If using UFW:

```bash
# Allow Docker ports
sudo ufw default allow incoming from 172.17.0.0/16

# Or disable UFW (for development)
sudo ufw disable
```

### Creating Custom Networks

**Bridge Network (isolated containers):**

```bash
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  my-network

# Run containers on network
docker run -d --network my-network --name web nginx
docker run -d --network my-network --name db postgres

# Containers can communicate by name
docker exec web ping db
```

**Host Network (container shares host network):**

```bash
docker run -d --network host --name web nginx
# Container port 80 = host port 80
```

### DNS Configuration

Docker daemon configuration includes DNS servers:

```bash
# View current DNS
docker info | grep DNS

# Edit /etc/docker/daemon.json:
{
  "dns": ["8.8.8.8", "8.8.4.4", "1.1.1.1"]
}

sudo systemctl restart docker
```

---

## Docker Daemon Configuration

### Daemon Configuration File

Docker daemon settings are in `/etc/docker/daemon.json`:

```bash
sudo cat /etc/docker/daemon.json
```

Example configuration:

```json
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
```

**Configuration Explanation:**

| Setting | Purpose |
|---------|----------|
| `log-driver` | Use JSON file for container logs |
| `max-size` | Rotate logs at 100MB |
| `max-file` | Keep maximum 10 log files |
| `dns` | Custom DNS servers for containers |
| `userland-proxy` | Use userland proxy for port mappings |
| `icc` | Inter-container communication enabled |
| `nofile ulimit` | Max open file descriptors |
| `storage-driver` | Use overlay2 storage (efficient) |

### Applying Configuration Changes

```bash
# Edit configuration
sudo nano /etc/docker/daemon.json

# Validate JSON
sudo docker run --rm -v /etc/docker:/etc/docker alpine \
  json_pp < /etc/docker/daemon.json > /dev/null && echo "Valid"

# Restart Docker
sudo systemctl restart docker

# Verify changes
docker info --format 'json' | jq '.LogDriver'
```

---

## Verification Steps

### Quick Verification

```bash
# Check Docker version
docker --version

# Check daemon status
sudo systemctl status docker

# Check docker group
getent group docker

# Run hello-world
docker run hello-world
```

### Comprehensive Verification

Run the provided verification script:

```bash
./scripts/verify.sh
```

This checks:
- Docker installation and version
- Daemon status and socket
- User group membership
- Network connectivity
- Storage driver
- Container runtime
- Docker image access

### Manual Comprehensive Tests

```bash
# 1. Daemon information
docker info

# 2. Check storage driver
docker info --format 'Storage Driver: {{.Driver}}'

# 3. List images
docker images

# 4. Run Alpine container
docker run --rm alpine echo "Docker works!"

# 5. Check container logs
docker run --rm alpine echo "Log test"

# 6. Network test
docker run --rm alpine ping -c 4 8.8.8.8

# 7. Pull image from registry
docker pull ubuntu:latest

# 8. Check disk usage
docker system df
```

---

## Post-Installation Configuration

### System Optimization

#### Kernel Parameters

Apply for Docker and Elasticsearch compatibility:

```bash
# Max memory mapping areas (for Elasticsearch)
sudo sysctl -w vm.max_map_count=262144

# Max file descriptors
sudo sysctl -w fs.file-max=2097152

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Make persistent
sudo tee -a /etc/sysctl.conf << EOF
vm.max_map_count=262144
fs.file-max=2097152
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF

sudo sysctl -p
```

#### User Limits

Increase file descriptor limits for containers:

```bash
# Temporary (current session)
ulimit -n 65536

# Permanent
sudo tee -a /etc/security/limits.conf << EOF
*       soft    nofile  65536
*       hard    nofile  65536
*       soft    nproc   32768
*       hard    nproc   32768
EOF

# Apply
sudo systemctl restart
```

### Container Limits

Set default resource limits:

```bash
# Edit daemon.json
sudo nano /etc/docker/daemon.json
```

Add:

```json
{
  "default-runtime": "runc",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    },
    "nproc": {
      "Name": "nproc",
      "Hard": 32768,
      "Soft": 32768
    }
  },
  "live-restore": true
}
```

### Enable Log Rotation

```bash
# Configure Docker log rotation
sudo tee /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "10"
  }
}
EOF

sudo systemctl restart docker
```

### Storage Optimization

Prune unused objects:

```bash
# Remove unused images, containers, networks, volumes
docker system prune -a --volumes

# Check disk usage
docker system df

# Clean up image cache
docker image prune -a
```

---

## Troubleshooting

### Docker Daemon Issues

**Problem: Docker daemon won't start**

```bash
# Check logs
sudo journalctl -u docker -n 50 --no-pager

# Or
sudo dockerd --debug

# Common issues:
# 1. Port already in use
sudo lsof -i :2375

# 2. Corrupt state
sudo rm -rf /var/lib/docker
sudo systemctl restart docker

# 3. Invalid configuration
sudo docker run --rm -v /etc/docker:/etc/docker alpine \
  json_pp < /etc/docker/daemon.json
```

### Permission Issues

**Problem: "Permission denied while trying to connect to Docker daemon"**

```bash
# Solution 1: Use sudo
sudo docker ps

# Solution 2: Add to docker group
sudo usermod -aG docker $USER
newgrp docker
docker ps

# Solution 3: Check socket permissions
ls -l /var/run/docker.sock
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock
```

### Network Issues

**Problem: Containers can't reach external networks**

```bash
# Check IP forwarding
sysctl net.ipv4.ip_forward

# Enable if disabled
sudo sysctl -w net.ipv4.ip_forward=1

# Test container connectivity
docker run --rm alpine ping -c 4 8.8.8.8

# Check iptables rules
sudo iptables -L -n

# Check Docker networks
docker network ls
docker network inspect bridge
```

### Storage Issues

**Problem: "No space left on device"**

```bash
# Check disk usage
df -h
du -sh /var/lib/docker

# Clean up
docker system prune -a --volumes
docker image prune -a
docker volume prune

# Reclaim disk
sudo docker volume rm $(docker volume ls -q)
```

### Container Issues

**Problem: Container won't start**

```bash
# Check logs
docker logs container-name
docker logs --tail 50 container-name

# Check container status
docker ps -a
docker inspect container-name

# Debug
docker run -it image-name /bin/bash
```

---

## Next Steps

1. **Security**: Review [SECURITY.md](SECURITY.md)
2. **Networking**: Review [NETWORKING.md](NETWORKING.md)
3. **Docker Compose**: Install and configure for multi-container apps
4. **Registry**: Setup private Docker registry if needed
5. **Monitoring**: Configure logging and monitoring
6. **Backup**: Plan backup strategy for volumes and images
