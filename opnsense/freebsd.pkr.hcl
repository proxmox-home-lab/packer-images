packer {
  required_version = ">= 1.11.0"
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.3"
    }
  }
}

variable "proxmox_url" {
  type    = string
  default = "https://xxx:8006/api2/json"
}
variable "proxmox_node" {
  type    = string
  default = "pve-1"
}
variable "proxmox_username" {
  type    = string
  default = "xxx"
} # ej: packer@pve!tokenid
variable "proxmox_token" {
  type    = string
  default = "xxx"
}

variable "vm_id" {
  type    = number
  default = 9600
}
variable "vm_name" {
  type    = string
  default = "freebsd-14.3-opnsense"
}
variable "storage_pool" {
  type    = string
  default = "local"
}
variable "bridge" {
  type    = string
  default = "vmbr1"
} # red privada con DHCP/NAT

source "proxmox-iso" "freebsd" {
  proxmox_url              = var.proxmox_url
  insecure_skip_tls_verify = true
  username                 = var.proxmox_username
  token                    = var.proxmox_token

  node    = var.proxmox_node
  vm_id   = var.vm_id
  vm_name = var.vm_name

  memory  = 4096
  cores   = 2
  sockets = 1

  disks {
    type         = "scsi"
    storage_pool = var.storage_pool
    disk_size    = "20G"
  }

  network_adapters {
    model  = "virtio"
    bridge = var.bridge
  }

  boot_iso {
    type         = "scsi"
    iso_file     = "local:iso/FreeBSD-14.3-RELEASE-amd64-disc1.iso"
    iso_checksum = "none" # puedes poner el SHA256 real
    unmount      = true
  }

  boot_wait = "30s"

  # Aquí podrías meter un script de bsdinstall, o dejar vacío y hacer instalación manual 1 vez
  boot_command = [
    "<enter><wait2><enter><wait2>opnsense<wait2><enter><wait2><enter><wait2><enter><wait2><enter><wait2><enter><wait2><spacebar><wait2><enter><wait2><left><wait2><enter><wait30s>changeme<enter>changeme<enter><wait2s><enter><wait2s><enter><wait2s><right><wait2s><enter><wait2s>172.16.0.50<wait2s><down><wait2s>24<wait2s><enter><wait2s><right><wait2s><enter><wait2s><enter><wait2s>8<wait2s><enter><wait2s>444444<wait2s><enter><wait2s><enter><wait2s><enter><wait2s><enter><wait2s><enter><wait2s><enter><wait2s><enter><wait2s><enter><wait2s><right><wait2s><enter><wait2s><enter><wait2s><enter><wait2s><enter>", # arranca instalador
    # Si usas un answers file puedes pasar argumentos aquí
  ]

  communicator                 = "ssh"
  ssh_username                 = "root"
  ssh_password                 = "changeme" # la clave que pongas en el instalador
  ssh_timeout                  = "30m"
  ssh_bastion_host             = "xxx"
  ssh_bastion_username         = "xxx"
  ssh_bastion_private_key_file = "key"
}

build {
  sources = ["source.proxmox-iso.freebsd"]

  provisioner "shell" {
    inline = [
      "pkg update -f",
      "pkg install -y curl ca_root_nss",
      "fetch -o /root/opnsense-bootstrap.sh https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in",
      "chmod +x /root/opnsense-bootstrap.sh -y -r \"25.7.2\"",
      "ASSUME_ALWAYS_YES=yes /root/opnsense-bootstrap.sh -y",
      "reboot"
    ]
  }
}