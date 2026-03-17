packer {
  required_version = ">= 1.11"
  required_plugins {
    proxmox = {
      version = ">= 1.2.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "proxmox_url" {
  description = "Proxmox API URL (e.g. https://192.168.1.10:8006/api2/json)."
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox API user (e.g. root@pam)."
  type        = string
}

variable "proxmox_token" {
  description = "Proxmox API token secret. Sensitive — inject via VAULT or CI secret."
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name to build on."
  type        = string
  default     = "pve"
}

variable "proxmox_storage" {
  description = "Proxmox storage pool to store the template."
  type        = string
  default     = "local"
}

variable "vyos_iso_url" {
  description = "URL to the VyOS rolling release ISO."
  type        = string
  default     = "https://github.com/vyos/vyos-rolling-nightly-builds/releases/download/1.5-rolling-202501070007/vyos-1.5-rolling-202501070007-amd64.iso"
}

variable "vyos_iso_checksum" {
  description = "SHA256 checksum of the VyOS ISO."
  type        = string
}

variable "vyos_api_key" {
  description = "VyOS HTTP API key to bake into the image. Sensitive — inject via Vault."
  type        = string
  sensitive   = true
}

variable "template_name" {
  description = "Name of the resulting Proxmox VM template."
  type        = string
  default     = "vyos-cloud-template"
}

variable "vm_id" {
  description = "Proxmox VM ID for the build VM."
  type        = number
  default     = 9001
}

# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

source "proxmox-iso" "vyos" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = false

  vm_id   = var.vm_id
  vm_name = var.template_name

  iso_url          = var.vyos_iso_url
  iso_checksum     = "sha256:${var.vyos_iso_checksum}"
  iso_storage_pool = var.proxmox_storage
  unmount_iso      = true

  cores  = 2
  memory = 1024

  disks {
    disk_size    = "4G"
    storage_pool = var.proxmox_storage
    type         = "virtio"
  }

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  ssh_username = "vyos"
  ssh_password = "vyos"
  ssh_timeout  = "20m"

  boot_command = [
    "<enter>",
    "<wait10>",
    "vyos<enter>",
    "<wait2>",
    "vyos<enter>",
    "<wait2>",
    "install image<enter>",
    "<wait60>",
    "Auto<enter>",
    "<wait5>",
    "<enter>",
    "<wait5>",
    "<enter>",
    "<wait5>",
    "vyos<enter>",
    "<wait5>",
    "vyos<enter>",
    "<wait60>",
    "reboot<enter>",
    "<wait60>",
    "vyos<enter>",
    "<wait2>",
    "vyos<enter>",
    "<wait10>",
  ]

  template_name        = var.template_name
  template_description = "VyOS rolling release with HTTP API enabled. Built by Packer."

  qemu_agent = false
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  name    = "vyos"
  sources = ["source.proxmox-iso.vyos"]

  # Enable VyOS HTTP API with a baked-in API key and static configuration
  # that does not change between environments (SSH, NTP, hostname pattern).
  # Dynamic configuration (interfaces, NAT, firewall) is applied by Terraform
  # via the Foltik/vyos provider after the VM is deployed.
  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/enable-api.sh",
      "${path.root}/scripts/static-config.sh",
    ]
    environment_vars = [
      "VYOS_API_KEY=${var.vyos_api_key}",
    ]
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
  }
}
