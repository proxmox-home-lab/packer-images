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
  description = "Proxmox API token secret. Sensitive — inject via Vault or CI secret."
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

variable "ubuntu_iso_url" {
  description = "URL to Ubuntu 24.04 LTS server ISO."
  type        = string
  default     = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso"
}

variable "ubuntu_iso_checksum" {
  description = "SHA256 checksum of the Ubuntu ISO."
  type        = string
}

variable "template_name" {
  description = "Name of the resulting Proxmox VM template."
  type        = string
  default     = "haproxy-cloud-template"
}

variable "vm_id" {
  description = "Proxmox VM ID for the build VM."
  type        = number
  default     = 9002
}

variable "ssh_public_key" {
  description = "SSH public key injected into the build VM for Packer access."
  type        = string
}

# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

source "proxmox-iso" "haproxy" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = false

  vm_id   = var.vm_id
  vm_name = var.template_name

  iso_url          = var.ubuntu_iso_url
  iso_checksum     = "sha256:${var.ubuntu_iso_checksum}"
  iso_storage_pool = var.proxmox_storage
  unmount_iso      = true

  cores  = 2
  memory = 2048

  disks {
    disk_size    = "20G"
    storage_pool = var.proxmox_storage
    type         = "virtio"
  }

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Ubuntu autoinstall via Cloud-Init compatible user-data
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<F10>",
  ]

  http_content = {
    "/user-data" = templatefile("${path.root}/http/user-data.yaml", {
      ssh_public_key = var.ssh_public_key
    })
    "/meta-data" = ""
  }

  ssh_username    = "ubuntu"
  ssh_private_key_file = "~/.ssh/id_ed25519"
  ssh_timeout     = "30m"

  template_name        = var.template_name
  template_description = "Ubuntu 24.04 with HAProxy pre-installed. Stats on :8404. Built by Packer."

  qemu_agent = true
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  name    = "haproxy"
  sources = ["source.proxmox-iso.haproxy"]

  # Install HAProxy and apply static base configuration (stats listener,
  # logging, base timeouts). Dynamic configuration (frontends, backends,
  # SSL certs) is applied by Ansible after deployment.
  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/install.sh",
      "${path.root}/scripts/static-config.sh",
    ]
    execute_command = "sudo bash -c '{{ .Path }}'"
  }
}
