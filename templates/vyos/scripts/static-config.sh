#!/bin/vbash
# Apply static VyOS configuration that is identical across all environments:
#   - SSH service with public-key auth only
#   - NTP servers
#   - Hostname pattern (overridden per-node at deploy time by Cloud-Init)
#   - System timezone
#
# Dynamic configuration (interfaces, VLANs, NAT, firewall, routes) is applied
# after deployment by the Foltik/vyos Terraform provider.

source /opt/vyatta/etc/functions/script-template

configure

# SSH: disable password authentication, enable public-key auth
set service ssh port 22
set service ssh disable-password-authentication

# NTP
set system ntp server 0.pool.ntp.org
set system ntp server 1.pool.ntp.org
set system ntp server 2.pool.ntp.org

# Timezone
set system time-zone UTC

# Hostname placeholder — Cloud-Init overrides this at deploy time
set system host-name vyos-node

commit
save

exit 0
