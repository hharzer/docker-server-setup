# Docker Server Setup

A production-ready project for preparing fresh Ubuntu servers to host Docker containers. Includes automated installation scripts, security hardening, networking configuration, user/group management, and best practices documentation.

**Supported Ubuntu Versions:** 20.04 LTS, 22.04 LTS, 24.04 LTS

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [What Gets Installed](#what-gets-installed)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
- [Configuration](#configuration)
- [Verification](#verification)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/docker-server-setup.git
cd docker-server-setup

# Make scripts executable
chmod +x scripts/*.sh

# Run the main setup script
sudo ./scripts/setup.sh

# Verify installation
./scripts/verify.sh
```

## 📁 Project Structure

```
docker-server-setup/
├── README.md                          # This file
├── GUIDE.md                          # Comprehensive setup guide
├── SECURITY.md                       # Security hardening guide
├── NETWORKING.md                     # Docker networking setup
├── scripts/
│   ├── setup.sh                      # Main automated setup
│   ├── install-docker.sh             # Docker installation
│   ├── setup-users.sh                # User/group configuration
│   ├── setup-networking.sh           # Network configuration
│   ├── verify.sh                     # Verification script
│   └── cleanup.sh                    # Cleanup utility
├── config/
│   ├── docker-daemon.json            # Docker daemon config
│   ├── limits.conf                   # System limits
│   └── sysctl.conf                   # Kernel parameters
├── examples/
│   ├── docker-compose.yml            # Example compose file
│   └── Dockerfile                    # Example Dockerfile
└── tests/
    └── test-docker.sh                # Test script
```

## 🔧 What Gets Installed

### Core Components
- **Docker Engine** (CE) - Latest stable version
- **Docker CLI** - Command-line interface
- **containerd** - Container runtime
- **Docker Compose** - Optional multi-container orchestration

### System Packages
- `apt-transport-https` - HTTPS package downloads
- `ca-certificates` - SSL/TLS certificates
- `curl` - HTTP client utility
- `software-properties-common` - Repository management
- `gpg` - GNU Privacy Guard for GPG keys

### Security & Monitoring (Optional)
- UFW firewall rules for container networking
- Audit logging configuration
- Kernel parameter optimization

## ✨ Features

### 🔒 Security
- GPG key verification for Docker repository
- Non-root user Docker access via docker group
- Daemon socket permissions validation
- Security recommendations documentation
- Audit logging setup

### 👥 User Management
- Automated docker group creation
- User addition to docker group with newgrp refresh
- Support for multiple users
- Sudo access configuration options

### 🌐 Networking
- Bridge network configuration
- DNS resolution setup
- Port forwarding rules
- Host network access control
- Custom network creation guide

### ⚙️ System Configuration
- Kernel parameter tuning (vm.max_map_count, fs.file-max)
- System limits configuration (ulimit)
- Automatic startup on boot
- Log rotation setup
- Storage optimization

### 📊 Verification & Testing
- Installation verification
- Docker version check
- Daemon status verification
- User group membership validation
- Hello-world container test
- Network connectivity test

## 📋 Prerequisites

- Fresh Ubuntu 20.04, 22.04, or 24.04 LTS installation
- `sudo` access on the system
- Internet connectivity
- 2GB+ RAM recommended
- 20GB+ disk space recommended
- Kernel 4.15+ (typically pre-installed)

## 💻 Installation Methods

### Method 1: Automated (Recommended)
```bash
sudo ./scripts/setup.sh
```
Runs all setup steps automatically with prompts.

### Method 2: Step-by-Step
```bash
sudo ./scripts/install-docker.sh
sudo ./scripts/setup-users.sh
sudo ./scripts/setup-networking.sh
./scripts/verify.sh
```

### Method 3: Manual
Follow `GUIDE.md` for manual installation steps.

### Method 4: Quick Install (Docker Official)
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

## ⚙️ Configuration

### Docker Daemon Configuration
The `config/docker-daemon.json` includes:
- Log rotation (max 10 files, 100M each)
- Proper DNS settings
- Resource limits
- Storage optimization

Apply custom config:
```bash
sudo cp config/docker-daemon.json /etc/docker/daemon.json
sudo systemctl restart docker
```

### System Limits
Update container resource limits:
```bash
sudo cp config/limits.conf /etc/security/limits.conf
sudo sysctl -p
```

### Kernel Parameters
Apply performance tuning:
```bash
sudo sysctl -w vm.max_map_count=262144
```

## ✅ Verification

Run the verification script:
```bash
./scripts/verify.sh
```

This checks:
- Docker installation and version
- Docker daemon status
- User group membership
- Docker socket permissions
- Network connectivity
- Container runtime test

## 🔐 Security Considerations

### Docker Group Privileges
⚠️ **Important:** Adding a user to the docker group effectively grants them root-equivalent privileges. Only add trusted users.

```bash
# Users in docker group can:
docker run -v /:/host busybox     # Mount entire filesystem
docker run --privileged bash      # Access host kernel
```

See `SECURITY.md` for:
- Non-root Docker daemon setup
- AppArmor and SELinux policies
- Network isolation techniques
- Image scanning recommendations
- Registry authentication

### Best Practices
- Use official Docker images only
- Enable Docker Content Trust (DCT)
- Scan images for vulnerabilities
- Use resource limits
- Run containers as non-root
- Keep Docker updated

## 🐛 Troubleshooting

### Docker daemon won't start
```bash
# Check logs
sudo journalctl -u docker -n 50

# Restart service
sudo systemctl restart docker
```

### Permission denied errors
```bash
# Verify group membership
groups $USER

# Apply membership to current session
newgrp docker

# Or logout and login again
```

### Network issues
```bash
# Check networks
docker network ls

# Inspect network
docker network inspect bridge

# Test connectivity
docker run alpine ping 8.8.8.8
```

### High memory usage
```bash
# Review running containers
docker stats

# Set memory limits
docker run -m 512m image-name
```

See `GUIDE.md` for more troubleshooting steps.

## 📚 Additional Resources

- [Official Docker Documentation](https://docs.docker.com/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Docker Networking Guide](https://docs.docker.com/network/)
- [Linux Post-Installation Steps](https://docs.docker.com/engine/install/linux-postinstall/)

## 📝 License

MIT License - see LICENSE file

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test on fresh Ubuntu instances
4. Submit a pull request

## ⚠️ Disclaimer

Use at your own risk. Always test on non-production systems first. Review all scripts before execution with `sudo`.
