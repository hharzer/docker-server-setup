# Docker Security Hardening Guide

Best practices and advanced security configurations for Docker servers.

## Table of Contents

1. [Understanding Docker Security Risks](#understanding-docker-security-risks)
2. [Docker Group Security](#docker-group-security)
3. [Running Docker as Non-Root](#running-docker-as-non-root)
4. [Image Security](#image-security)
5. [Container Runtime Security](#container-runtime-security)
6. [Network Security](#network-security)
7. [Audit and Logging](#audit-and-logging)
8. [AppArmor and SELinux](#apparmor-and-selinux)
9. [Security Scanning](#security-scanning)
10. [Compliance and Best Practices](#compliance-and-best-practices)

---

## Understanding Docker Security Risks

### The Docker Group Issue

Adding a user to the `docker` group grants **root-equivalent privileges**.

**What docker group members can do:**

```bash
# Mount host filesystem
docker run -v /:/host alpine ls /host

# Access host files as root
docker run -v /etc:/etc alpine cat /etc/shadow

# Run privileged containers
docker run --privileged alpine

# Modify system state
docker run -v /sys:/sys alpine sysctl -w kernel.panic=1
```

**Security Implication:**
> Only add trusted users to the docker group. Treat it like root access.

### Container Isolation

Docker containers are **not isolated at all from each other by default**:
- Share same kernel
- Can communicate via default bridge network
- May access shared host resources
- Possible to escape to host in some configurations

---

## Docker Group Security

### Audit Docker Group Membership

```bash
# List all docker group members
getent group docker

# Check individual user
groups username

# Verify permissions
ls -l /var/run/docker.sock
```

### Restrict Docker Group Access

**Option 1: Use Sudo Instead**

Instead of adding to docker group:

```bash
# Create sudoers entry
sudo visudo -f /etc/sudoers.d/docker

# Add:
username ALL=(root) NOPASSWD: /usr/bin/docker

# Benefit: Audit trail of all docker commands
# Usage: sudo docker run ...
```

**Option 2: Limit Specific Commands**

```bash
# Only allow pull and run
username ALL=(root) NOPASSWD: /usr/bin/docker pull *, /usr/bin/docker run *
```

**Option 3: Central Authorization**

```bash
# Use Akkeris or similar for centralized access control
# or implement custom authorization wrapper
```

### Remove Users from Docker Group

```bash
# Remove specific user
sudo deluser username docker

# Verify
getent group docker

# User needs to logout/login for changes to take effect
```

---

## Running Docker as Non-Root

### Rootless Docker Mode

Run Docker daemon as non-root user (experimental but stable):

```bash
# Prerequisites
sudo apt install dbus-user-session fuse-overlayfs

# Install rootless Docker
dockerctl:rootless-install

# Or manually:
script -q -c 'dockerd-rootless-setuptool.sh install' /dev/null

# Enable rootless mode
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

# Add to ~/.bashrc:
echo 'export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock' >> ~/.bashrc

# Test
docker ps
```

### Rootless Mode Benefits

- No docker group needed
- User cannot access host filesystem
- Reduced attack surface
- Each user has isolated Docker daemon

### Rootless Mode Limitations

- Some features unavailable ("Cannot use cgroup-v1 memory limit")
- Performance slightly lower
- Not default installation
- Requires additional configuration

### Uninstall Rootless Mode

```bash
script -q -c 'dockerctl:rootless-uninstall' /dev/null
```

---

## Image Security

### Use Official Images Only

```bash
# Good - official image
docker pull ubuntu
docker pull nginx

# Bad - untrusted third-party
docker pull randomuser/someimage
```

### Enable Docker Content Trust

Ensure only signed, verified images are pulled:

```bash
# Enable DCT (requires ~/.docker/config.json setup)
export DOCKER_CONTENT_TRUST=1

# Now only signed images work
docker pull ubuntu  # Works if signed

# Unsigned images fail
docker pull unsigned-image  # Error

# Add to ~/.bashrc:
echo 'export DOCKER_CONTENT_TRUST=1' >> ~/.bashrc
```

### Image Scanning for Vulnerabilities

#### Docker Scout (Built-in)

```bash
# Scan image for vulnerabilities
docker scout cves nginx:latest
docker scout cves ubuntu:22.04

# Compare base images
docker scout compare nginx:latest nginx:1.24
```

#### Trivy (Third-party)

```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan image
trivy image nginx:latest
trivy image --severity HIGH,CRITICAL ubuntu:22.04

# Generate report
trivy image -f json nginx:latest > report.json
```

#### Grype (Anchore)

```bash
# Install
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Scan
grype ubuntu:22.04
grype --output sarif alpine:latest > results.sarif
```

### Minimal Base Images

Use lighter, more secure base images:

```dockerfile
# Bad - 77MB, many attack vectors
FROM ubuntu:22.04
RUN apt update && apt install curl

# Good - 7MB, minimal
FROM alpine:latest
RUN apk add --no-cache curl

# Better - 0.5MB, only app
FROM scratch
COPY --from=builder /app /
ENTRYPOINT ["/app"]
```

### Image Signing

```bash
# Sign image with private key
docker trust sign username/image:tag

# Verify signature
docker trust inspect username/image:tag

# Generate keys
docker trust key generate mykey
```

---

## Container Runtime Security

### Run Containers as Non-Root

```dockerfile
# In Dockerfile
RUN useradd -m -u 1000 appuser
USER appuser

# Verify
RUN whoami  # prints: appuser
```

```bash
# At runtime
docker run --user 1000:1000 nginx

# Verify
docker run --user 1000:1000 ubuntu id
# uid=1000 gid=1000 groups=1000
```

### Use Read-Only Filesystems

```bash
# Make container filesystem read-only
docker run --read-only nginx

# Allow only /tmp writable
docker run --read-only --tmpfs /tmp nginx
```

### Drop Linux Capabilities

```bash
# Don't use --privileged (grants all capabilities)
# Instead, drop unnecessary capabilities

# Drop all, add only needed
docker run \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  nginx

# View container capabilities
docker run --rm ubuntu capsh --print | grep Current
```

### Disable Privileged Mode

```bash
# NEVER use this in production
docker run --privileged ubuntu  # BAD

# This grants:
# - All capabilities
# - Access to all devices
# - Ability to modify kernel
# - Potential host escape

# Instead, request specific capabilities:
docker run --cap-add=SYS_ADMIN ubuntu
```

### Resource Limits

```bash
# Prevent resource exhaustion attacks

# Memory limit (512MB)
docker run -m 512m nginx

# CPU limit (1 CPU core)
docker run --cpus 1 nginx

# Swap limit (256MB)
docker run -m 512m --memory-swap 768m nginx

# PIDs limit (100 max processes)
docker run --pids-limit 100 nginx

# In docker-compose:
services:
  web:
    image: nginx
    mem_limit: 512m
    cpus: 1
    pids_limit: 100
```

### No New Privileges

```bash
# Prevent privilege escalation via setuid/setgid
docker run --security-opt=no-new-privileges ubuntu

# Or in docker-compose:
security_opt:
  - no-new-privileges:true
```

### Ulimit Configuration

```bash
# Limit file descriptors
docker run --ulimit nofile=1024:2048 nginx

# Limit process count
docker run --ulimit nproc=512:1024 nginx
```

---

## Network Security

### Default Network Isolation

```bash
# Containers can communicate by default on bridge network
# Enable restricted mode

# Edit /etc/docker/daemon.json:
{
  "icc": false,  # Disable inter-container communication
  "default-network": "restricted"
}

sudo systemctl restart docker
```

### Expose Only Necessary Ports

```bash
# Bad - expose all ports
docker run -P nginx

# Good - expose specific port
docker run -p 80:80 nginx

# Better - bind to localhost only
docker run -p 127.0.0.1:80:80 nginx
```

### Use Custom Networks

```bash
# Create isolated network
docker network create myapp-net

# Containers on this network are isolated
docker run --network myapp-net --name web nginx
docker run --network myapp-net --name db postgres

# They can communicate by name
docker exec web ping db

# But other containers cannot reach them
```

### DNS Security

```bash
# Override DNS for containers
docker run --dns 1.1.1.1 --dns 8.8.8.8 ubuntu

# In daemon.json:
{
  "dns": ["1.1.1.1", "8.8.8.8"]
}
```

### Firewall Configuration

```bash
# If using UFW

# Allow SSH
sudo ufw allow 22/tcp

# Allow specific Docker port
sudo ufw allow 80/tcp

# Deny by default, allow specific
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw enable
```

---

## Audit and Logging

### Docker Daemon Logging

```bash
# View Docker daemon logs
sudo journalctl -u docker -n 100
sudo journalctl -u docker -f  # Follow

# Configure logging
echo 'ForwardToConsole=yes' | sudo tee -a /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
```

### Container Logs

```bash
# View container logs
docker logs container-name

# Follow logs
docker logs -f container-name

# Last 100 lines
docker logs --tail 100 container-name

# With timestamps
docker logs -t container-name
```

### Audit Container Execution

```bash
# Track all docker commands
auditctl -w /var/lib/docker -p wa -k docker
auditctl -w /etc/docker -p wa -k docker
auditctl -w /usr/bin/docker -p x -k docker

# View audit logs
auditctl -l
auditctl -m list_rules
grep docker /var/log/audit/audit.log
```

### Enable Debug Logging

```bash
# Edit daemon.json
{
  "debug": true
}

sudo systemctl restart docker

# View debug logs
sudo journalctl -u docker -p debug
```

---

## AppArmor and SELinux

### AppArmor (Ubuntu)

AppArmor is enabled by default on Ubuntu.

```bash
# Check AppArmor status
sudo aa-status | grep docker

# Docker default profile
sudo cat /etc/apparmor.d/docker

# Create custom profile
sudo nano /etc/apparmor.d/docker-custom

# Load profile
sudo apparmor_parser -r /etc/apparmor.d/docker-custom

# Use custom profile
docker run --security-opt apparmor=docker-custom ubuntu

# Disable AppArmor for container
docker run --security-opt apparmor=unconfined ubuntu
```

### SELinux (CentOS/RHEL)

SELinux available on RHEL-based systems.

```bash
# Check SELinux status
sudo semanage fcontext -l | grep docker

# Run container with SELinux label
docker run -Z ubuntu
docker run -z ubuntu  # Shared label

# Check container labels
secon container-id
```

---

## Security Scanning

### Docker Benchmark

Test security configurations:

```bash
# Download Docker Bench Security
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security

# Run benchmark
./docker-bench-security.sh

# Generates report of passed/failed checks
```

### Vulnerability Scanning Workflow

```bash
# 1. Scan base image
trivy image ubuntu:22.04

# 2. Build application image
docker build -t myapp:latest .

# 3. Scan application image
trivy image myapp:latest

# 4. Fail build if HIGH or CRITICAL
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:latest
```

### CI/CD Integration

```yaml
# GitHub Actions example
name: Docker Image Security

on: [push]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build image
        run: docker build -t myapp:latest .
      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:latest'
          format: 'sarif'
          output: 'trivy-results.sarif'
      - name: Upload results
        uses: github/codeql-action/upload-sarif@v1
        with:
          sarif_file: 'trivy-results.sarif'
```

---

## Compliance and Best Practices

### Security Checklist

- [ ] Only add trusted users to docker group
- [ ] Use sudo instead of docker group when possible
- [ ] Scan all images for vulnerabilities
- [ ] Use official images from trusted registries
- [ ] Enable Docker Content Trust
- [ ] Run containers as non-root user
- [ ] Use read-only filesystems
- [ ] Drop unnecessary capabilities
- [ ] Never use `--privileged` in production
- [ ] Set resource limits on containers
- [ ] Use custom networks for container isolation
- [ ] Enable audit logging
- [ ] Keep Docker updated
- [ ] Review container logs regularly
- [ ] Use AppArmor/SELinux when available

### CIS Docker Benchmark Recommendations

1. **Image and Build**
   - Create dedicated user in image
   - Use specific image versions (not `latest`)
   - Scan images for vulnerabilities
   - Sign images

2. **Container Runtime**
   - Run containers as non-root
   - Use read-only filesystems
   - Bind mount read-only where possible
   - Drop unnecessary capabilities
   - Don't use privileged containers

3. **Host Configuration**
   - Verify Docker daemon is not exposed
   - Restrict Docker socket permissions
   - Disable inter-container communication
   - Use AppArmor/SELinux
   - Enable audit logging

4. **Access Control**
   - Restrict docker group membership
   - Use authentication plugins
   - Implement authorization policies
   - Regularly audit permissions

### NIST Recommendations

Refer to [NIST Application Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)

---

## Summary

Key security principles:

1. **Principle of Least Privilege**: Grant minimal necessary permissions
2. **Defense in Depth**: Use multiple security layers
3. **Continuous Monitoring**: Audit and log all activity
4. **Stay Updated**: Keep Docker and images current
5. **Secure by Default**: Use secure configurations from the start
