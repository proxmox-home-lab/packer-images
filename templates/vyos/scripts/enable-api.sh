#!/bin/vbash
# Enable the VyOS HTTP API with the provided API key and set it to listen
# on localhost:8443. This is baked into the image so the Foltik/vyos Terraform
# provider can connect immediately after the VM is deployed.
#
# VYOS_API_KEY: injected by Packer as an environment variable from Vault.

source /opt/vyatta/etc/functions/script-template

if [[ -z "${VYOS_API_KEY:-}" ]]; then
  echo "ERROR: VYOS_API_KEY is not set"
  exit 1
fi

configure

set service https api keys id packer key "${VYOS_API_KEY}"
set service https api socket
set service https listen-address 0.0.0.0
set service https port 8443

commit
save

exit 0
