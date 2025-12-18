# Docker Networking Configuration Guide

Comprehensive guide to Docker networking, bridge networks, overlays, and DNS configuration.

## Table of Contents

1. [Networking Fundamentals](#networking-fundamentals)
2. [Default Networks](#default-networks)
3. [Bridge Networks](#bridge-networks)
4. [Host Networks](#host-networks)
5. [Overlay Networks](#overlay-networks)
6. [DNS Resolution](#dns-resolution)
7. [Port Mapping](#port-mapping)
8. [Network Security](#network-security)
9. [Troubleshooting](#troubleshooting)

---

## Networking Fundamentals

### Docker Network Types

| Type | Use Case | Isolation |
|------|----------|----------|
| **bridge** | Default, single host | Per network |
| **host** | Maximum performance | None (shares host network) |
| **overlay** | Multi-host, Swarm/K8s | Encrypted |
| **macvlan** | Legacy apps, static IPs | Full VLAN isolation |
| **ipvlan** | Flat network topology | Full VLAN isolation |
| **none** | No networking | Complete isolation |

### Key Concepts

**IP Forwarding**: Enables containers to reach external networks

```bash
# Check status
sysctl net.ipv4.ip_forward

# Enable permanently
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

**DNS**: How containers resolve domain names

```bash
# View container DNS
docker inspect container-name | jq '.[0].HostConfig.Dns'
```

**Port Forwarding**: Exposing container ports to host

```bash
# Map port 8080 (host) to 80 (container)
docker run -p 8080:80 nginx
```

---

## Default Networks

### Bridge Network (Default)

Default network created automatically with Docker installation.

```bash
# View networks
docker network ls

# Output:
NETWORK ID     NAME      DRIVER    SCOPE
1234567890ab   bridge    bridge    local
abcd1234efgh   host      host      local
efgh5678ijkl   none      null      local
```

### Inspect Bridge Network

```bash
# Detailed network info
docker network inspect bridge

# Output includes:
# - IPAM (IP Address Management)
# - Containers connected
# - Driver options
# - Subnet and gateway
```

### Connect Container to Bridge

```bash
# New container (automatic)
docker run -d --name web nginx

# Check connection
docker network inspect bridge | jq '.Containers'

# Connect running container
docker network connect bridge container-name

# Disconnect
docker network disconnect bridge container-name
```

### Bridge Network Limitations

- Only single-host networking
- Container names not resolvable by default
- Less flexible than custom bridges

---

## Bridge Networks

### Create Custom Bridge Network

```bash
# Basic creation
docker network create myapp-net

# With options
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --ip-range 172.20.240.0/20 \
  --gateway 172.20.0.1 \
  --opt com.docker.network.bridge.name=br-myapp \
  myapp-net
```

### Benefits of Custom Bridges

- **Better isolation**: Separate from default bridge
- **DNS resolution**: Container names resolvable
- **Subnet control**: Choose specific IP ranges
- **Fine-grained access**: Control which containers connect

### Using Custom Network

```bash
# Run container on custom network
docker run -d \
  --network myapp-net \
  --name web \
  nginx

# Run another container
docker run -d \
  --network myapp-net \
  --name db \
  postgres

# Containers can communicate by name
docker exec web ping db
# PING db (172.20.0.3) 56(84) bytes of data.
# 64 bytes from db.myapp-net (172.20.0.3): icmp_seq=1 ttl=64 time=0.1ms

# Reverse DNS works
docker exec web nslookup db
# Server:         127.0.0.11
# Address:        127.0.0.11#53
# Name:   db
# Address: 172.20.0.3
```

### Network Without Internet Access

```bash
# Create isolated network (no gateway route)
docker network create \
  --driver bridge \
  --internal \
  isolated-net

# Containers cannot reach external networks
docker run --network isolated-net -it alpine
# In container: ping 8.8.8.8 - will fail
```

### Remove Network

```bash
# List networks
docker network ls

# Remove
docker network rm myapp-net

# All unused networks
docker network prune
```

---

## Host Networks

### Using Host Network

```bash
# Container uses host network stack directly
docker run -d --network host --name web nginx

# Container port 80 = Host port 80 (no isolation)
# Access via http://localhost:80
```

### Host Network Characteristics

- **No IP isolation**: Shares host IP addresses
- **Maximum performance**: No virtualization overhead
- **Port conflicts**: Can't have two containers on same port
- **Limited portability**: Not available on Docker Desktop Mac/Windows
- **Security implications**: Less isolation from host

### When to Use Host Network

- High-performance applications
- Monitoring agents (Prometheus, etc.)
- Network utilities (tcpdump, etc.)
- Legacy network-dependent apps

### Example: Monitoring Stack

```bash
# Prometheus on host network for direct access
docker run -d \
  --network host \
  --name prometheus \
  -v /etc/prometheus:/etc/prometheus \
  prom/prometheus

# Access via http://localhost:9090
```

---

## Overlay Networks

### Overlay Network Setup

Overlay networks enable multi-host communication in Docker Swarm.

```bash
# Initialize Docker Swarm
docker swarm init

# Create overlay network
docker network create \
  --driver overlay \
  --subnet 10.0.0.0/24 \
  --opt encrypted \
  app-net

# Deploy service on overlay
docker service create \
  --network app-net \
  --name web \
  nginx
```

### Overlay Network Features

- **Multi-host**: Containers on different hosts can communicate
- **Encryption**: Optional encryption with `--opt encrypted`
- **Service discovery**: Built-in DNS load balancing
- **Isolated networks**: Each network is separate

### Swarm Service Discovery

```bash
# Services auto-register in DNS
# Containers can reach: service-name:port

# Multiple replicas load-balanced
docker service create \
  --network app-net \
  --replicas 3 \
  --name web \
  nginx

# Requests to 'web' distributed across 3 replicas
```

---

## DNS Resolution

### Docker Embedded DNS

Docker includes embedded DNS server at 127.0.0.11:53

```bash
# View DNS settings
docker inspect container-name | jq '.[0].HostConfig.Dns'

# Check DNS resolver
docker exec container-name cat /etc/resolv.conf
# Output:
# nameserver 127.0.0.11
# options ndots:0
```

### Container Name Resolution

```bash
# Create network and containers
docker network create testnet
docker run -d --network testnet --name web nginx
docker run -d --network testnet --name db postgres

# Resolve by name
docker exec web nslookup db
docker exec web ping db
```

### Configuring DNS

#### Override DNS Servers

```bash
# At runtime
docker run --dns 8.8.8.8 --dns 8.8.4.4 ubuntu

# In daemon.json
{
  "dns": ["8.8.8.8", "8.8.4.4", "1.1.1.1"]
}

sudo systemctl restart docker
```

#### DNS Options

```bash
# Set search domain
docker run --dns-search example.com ubuntu

# Set DNS options
docker run --dns-opt ndots:2 --dns-opt timeout:1 ubuntu

# In docker-compose.yml
services:
  web:
    image: nginx
    dns:
      - 8.8.8.8
      - 8.8.4.4
    dns_search:
      - example.com
    dns_opt:
      - ndots:2
```

### Troubleshooting DNS

```bash
# Test DNS resolution
docker run --rm alpine nslookup google.com

# Check DNS configuration
docker exec container-name cat /etc/resolv.conf

# Query specific nameserver
docker run --rm ubuntu nslookup google.com 8.8.8.8

# Verbose DNS queries
docker run --rm ubuntu dig google.com
docker run --rm ubuntu host google.com
```

---

## Port Mapping

### Port Mapping Syntax

```bash
# Map container port to host
docker run -p 8080:80 nginx
# Host 8080 → Container 80

# Specify IP address
docker run -p 127.0.0.1:8080:80 nginx
# Only accessible on localhost

# Map multiple ports
docker run -p 8080:80 -p 8443:443 nginx

# Random host port
docker run -p 80 nginx
# Host assigns random port (e.g., 32768)

# UDP port
docker run -p 53:53/udp dns

# Both TCP and UDP
docker run -p 80:80/tcp -p 80:80/udp myapp
```

### Port Ranges

```bash
# Map port range
docker run -p 8000-8100:8000-8100 myapp

# Specific interface and range
docker run -p 127.0.0.1:8000-8100:8000-8100 myapp
```

### Finding Mapped Ports

```bash
# View port mappings
docker port container-name
# Output:
# 80/tcp -> 0.0.0.0:8080
# 443/tcp -> 0.0.0.0:8443

# Get specific port
docker port container-name 80
# Output: 0.0.0.0:8080

# In inspect output
docker inspect container-name | jq '.[0].NetworkSettings.Ports'
```

### Dynamic Port Discovery

```bash
# Start container with random port
CONTAINER_ID=$(docker run -d -p 80 nginx)

# Get assigned port
PORT=$(docker port $CONTAINER_ID 80 | cut -d':' -f2)
echo "Container accessible at localhost:$PORT"
```

---

## Network Security

### Disable Inter-Container Communication

```bash
# Edit daemon.json
{
  "icc": false
}

sudo systemctl restart docker

# Now containers cannot reach each other
# Only exposed ports are accessible
```

### Custom Network Isolation

```bash
# Create isolated networks
docker network create frontend
docker network create backend

# Run web container only on frontend
docker run -d --network frontend --name web nginx

# Run db container only on backend
docker run -d --network backend --name db postgres

# web cannot reach db (different networks)

# Connect app container to both
docker run -d \
  --network frontend \
  --name app \
  myapp

docker network connect backend app

# app can reach both web and db
```

### Firewall Rules

```bash
# UFW firewall configuration
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow specific ports
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS

# Allow Docker networks
sudo ufw allow from 172.17.0.0/16  # Default bridge
sudo ufw allow from 172.18.0.0/16  # Custom bridges

sudo ufw enable
```

### Network Policy (Kubernetes)

For Kubernetes deployments:

```yaml
# Allow ingress from specific pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 5432
```

---

## Troubleshooting

### Container Can't Reach External Network

```bash
# Test connectivity
docker run --rm alpine ping 8.8.8.8

# Check IP forwarding
sysctl net.ipv4.ip_forward

# Enable if needed
sudo sysctl -w net.ipv4.ip_forward=1

# Check iptables rules
sudo iptables -L -n
sudo iptables -L -n -t nat

# Reset Docker networking
sudo systemctl restart docker
```

### Container Can't Resolve Hostnames

```bash
# Test DNS
docker run --rm alpine nslookup google.com

# Check DNS configuration
docker run --rm alpine cat /etc/resolv.conf

# Check daemon DNS settings
sudo docker inspect --format='{{.HostConfig.Dns}}' container

# Override DNS
docker run --dns 8.8.8.8 --rm alpine nslookup google.com
```

### Port Already in Use

```bash
# Find process using port
sudo lsof -i :8080

# Kill process
sudo kill -9 PID

# Or use different port
docker run -p 8081:80 nginx
```

### Cannot Connect Between Containers

```bash
# Verify network
docker network ls
docker network inspect network-name

# Check containers on network
docker exec container-1 ifconfig

# Test connectivity
docker exec container-1 ping container-2

# Check DNS
docker exec container-1 nslookup container-2

# If on different networks, connect:
docker network connect network-name container
```

### High Network Latency

```bash
# Test latency
docker exec container ping host.docker.internal

# Check network mode
docker inspect --format='{{.HostConfig.NetworkMode}}' container

# Use host network if performance critical
docker run --network host container

# Reduce DNS lookups
# Cache DNS responses in container
```

---

## Best Practices

1. **Use custom networks** for production apps
2. **Enable DNS resolution** by name
3. **Isolate networks** for security
4. **Map only needed ports**
5. **Use specific subnets** to avoid conflicts
6. **Enable IP forwarding** for external connectivity
7. **Configure DNS** for container-specific needs
8. **Use network policies** in Kubernetes
9. **Monitor network traffic** for debugging
10. **Test connectivity** during setup
