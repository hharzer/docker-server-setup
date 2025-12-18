# Docker Quick Reference

Common Docker commands and operations for server management.

## Installation & Setup

```bash
# Quick automated setup
sudo ./scripts/setup.sh

# Verify installation
./scripts/verify.sh

# Add user to docker group
sudo usermod -aG docker username
newgrp docker  # Apply immediately
```

## Container Operations

```bash
# Run container
docker run -d --name web -p 8080:80 nginx

# List containers
docker ps              # Running
docker ps -a           # All

# View logs
docker logs container-name
docker logs -f container-name    # Follow
docker logs --tail 50 container-name

# Execute command in container
docker exec -it container-name bash

# Stop/Start/Restart
docker stop container-name
docker start container-name
docker restart container-name

# Remove container
docker rm container-name
docker rm $(docker ps -aq)      # All stopped

# View container details
docker inspect container-name
docker stats                    # Live stats
```

## Image Operations

```bash
# Pull image
docker pull nginx:latest

# List images
docker images

# Build image
docker build -t myapp:1.0 .

# Tag image
docker tag myapp:1.0 myrepo/myapp:latest

# Push image
docker push myrepo/myapp:latest

# Remove image
docker rmi image-name
docker rmi $(docker images -q)  # All unused

# Search images
docker search ubuntu
```

## Network Operations

```bash
# List networks
docker network ls

# Inspect network
docker network inspect bridge

# Create network
docker network create mynet

# Connect container to network
docker network connect mynet container-name

# Disconnect container from network
docker network disconnect mynet container-name

# Remove network
docker network rm mynet
```

## Volume Operations

```bash
# List volumes
docker volume ls

# Create volume
docker volume create myvolume

# Inspect volume
docker volume inspect myvolume

# Mount volume in container
docker run -v myvolume:/app/data nginx

# Bind mount from host
docker run -v /host/path:/container/path nginx

# Remove volume
docker volume rm myvolume
docker volume prune     # All unused
```

## System Operations

```bash
# System information
docker info
docker version

# Disk usage
docker system df

# Cleanup unused resources
docker system prune          # Containers, images, networks
docker system prune -a       # Include unused images
docker system prune --volumes # Include volumes

# Daemon logs
sudo journalctl -u docker -n 100
sudo journalctl -u docker -f    # Follow
```

## Docker Compose

```bash
# Start services
docker-compose up -d

# View status
docker-compose ps

# View logs
docker-compose logs
docker-compose logs -f service-name

# Execute command
docker-compose exec service-name bash

# Stop services
docker-compose stop

# Remove services and volumes
docker-compose down
docker-compose down -v      # Include volumes

# Rebuild images
docker-compose build
docker-compose up -d --build
```

## Useful Debugging Commands

```bash
# Port mapping check
docker port container-name

# Container IP address
docker inspect container-name | grep IPAddress

# View environment variables
docker inspect container-name | grep -A 20 Environment

# DNS resolution
docker exec container-name nslookup example.com

# Network connectivity
docker exec container-name ping 8.8.8.8

# Container processes
docker top container-name

# Container differences
docker diff container-name

# Export logs to file
docker logs container-name > logs.txt
```

## Useful Aliases

Add to ~/.bashrc or ~/.zshrc:

```bash
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dpl='docker ps --latest'
alias drm='docker rm'
alias drmi='docker rmi'
alias dlog='docker logs'
alias dlogf='docker logs -f'
alias dex='docker exec -it'
alias dinspect='docker inspect'
alias dstats='docker stats'
alias dprune='docker system prune -a'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
alias dcps='docker-compose ps'
alias dclogs='docker-compose logs'
alias dcexec='docker-compose exec'
```

## User/Group Management

```bash
# Add user to docker group
sudo usermod -aG docker username

# List docker group members
getent group docker

# Check user groups
groups username

# Remove user from docker group
sudo deluser username docker

# Fix socket permissions
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock
```

## Security Commands

```bash
# Scan image for vulnerabilities (requires trivy)
trivy image nginx:latest

# Docker benchmark security check
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security
./docker-bench-security.sh

# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1

# Verify image signature
docker trust inspect image-name:tag
```

## Performance Tuning

```bash
# Set memory limit
docker run -m 512m nginx

# Set CPU limit
docker run --cpus 1 nginx

# Set PIDs limit
docker run --pids-limit 100 nginx

# View container resource usage
docker stats
docker stats container-name
```

## Help Commands

```bash
# Get help for command
docker --help
docker run --help
docker network --help

# View full documentation
man docker
```

## Common Troubleshooting

```bash
# Connection refused?
# 1. Check if container is running
docker ps

# 2. Check logs
docker logs container-name

# 3. Check port mapping
docker port container-name

# Permission denied?
# 1. Check user in docker group
groups $USER

# 2. Apply group changes
newgrp docker

# 3. Or use sudo
sudo docker ps

# DNS resolution fails?
# 1. Check DNS settings
docker exec container-name cat /etc/resolv.conf

# 2. Override DNS
docker run --dns 8.8.8.8 container-name

# Out of disk space?
# 1. Check usage
docker system df

# 2. Clean up
docker system prune -a --volumes
```

## Useful Docker Run Flags

```bash
-d              # Detached mode (background)
-it             # Interactive terminal
-p 8080:80      # Port mapping
-e VAR=value    # Environment variable
-v /host:/cont  # Volume mount
--name name     # Container name
--network net   # Network
--restart=always # Auto restart
--user user     # Run as user
-m 512m         # Memory limit
--cpus 1        # CPU limit
--read-only     # Read-only filesystem
--cap-drop=ALL  # Drop capabilities
-h hostname     # Hostname
--dns 8.8.8.8   # DNS server
--rm            # Auto-remove on exit
```

## Production Checklist

- [ ] Review SECURITY.md
- [ ] Enable IP forwarding: `sysctl net.ipv4.ip_forward=1`
- [ ] Set resource limits on containers
- [ ] Configure logging (max-size, max-file)
- [ ] Setup monitoring and health checks
- [ ] Review network configuration
- [ ] Backup volumes regularly
- [ ] Keep Docker updated: `sudo apt update && sudo apt upgrade -y`
- [ ] Scan images for vulnerabilities
- [ ] Use read-only filesystems where possible
- [ ] Run containers as non-root
- [ ] Enable Docker Content Trust
- [ ] Setup log rotation
- [ ] Configure firewall rules
- [ ] Document network architecture
