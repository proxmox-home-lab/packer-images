#!/usr/bin/env bash
set -euo pipefail

# Install HAProxy (LTS version from Ubuntu repos) and rsyslog for logging.
# This is the only step that needs network access during the Packer build.

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y --no-install-recommends \
  haproxy \
  rsyslog \
  curl \
  ca-certificates

# Enable and start rsyslog (required for HAProxy log drain)
systemctl enable rsyslog

# Prevent haproxy from starting on boot until Ansible configures it
systemctl disable haproxy

echo "HAProxy version: $(haproxy -v | head -1)"
