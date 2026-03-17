#!/usr/bin/env bash
set -euo pipefail

# Write a static HAProxy base configuration that is identical across all
# environments. This establishes:
#   - Global settings (logging, maxconn, tuning)
#   - Stats listener on :8404 (always accessible for monitoring)
#   - Base timeouts
#
# Dynamic configuration (frontends, backends, SSL certificates) is written
# by Ansible after the VM is deployed.

cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 50000

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5s
    timeout client  50s
    timeout server  50s
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

# Stats listener — always enabled, used by monitoring and oncall.
# Port 8404 is NOT exposed externally; VyOS firewall blocks it from WAN.
frontend stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats show-legends
    stats show-node
    no log

# Placeholder frontend — replaced by Ansible with real backends.
# HAProxy requires at least one frontend to start.
frontend placeholder
    bind *:80
    mode http
    default_backend placeholder_backend

backend placeholder_backend
    mode http
    server placeholder 127.0.0.1:8080 check
EOF

# Configure rsyslog to receive HAProxy logs on local socket
cat > /etc/rsyslog.d/49-haproxy.conf << 'EOF'
$AddUnixListenSocket /var/lib/haproxy/dev/log

:programname, startswith, "haproxy" {
  /var/log/haproxy.log
  stop
}
EOF

# Create HAProxy chroot socket directory
mkdir -p /var/lib/haproxy/dev

echo "HAProxy static config written to /etc/haproxy/haproxy.cfg"
