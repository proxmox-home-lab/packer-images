packer {
  required_version = ">= 1.11.0"
  required_plugins {
    proxmox = { source = "github.com/hashicorp/proxmox", version = ">= 1.2.3" }
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
  default = 9500
}
variable "vm_name" {
  type    = string
  default = "opnsense-25-7-build"
}
variable "storage_pool" {
  type    = string
  default = "local"
}
variable "wan_bridge" {
  type    = string
  default = "vmbr0"
}
variable "lan_bridge" {
  type    = string
  default = "vmbr1"
}

locals {
  slowdown  = "" # puedes poner "<wait1s>" si te faltan tiempos
  fetch_cfg = "fetch -o /conf/config.xml http://{{ .HTTPIP }}:{{ .HTTPPort }}/config.xml"
  boot_steps = [
    # login live (usuario installer / pass opnsense)
    "installer<enter><wait500ms>opnsense<enter><wait2s>",
    # aceptar defaults del instalador (ajusta según ISO)
    "<enter><wait2s><enter><wait2s><enter><wait2s>",
    # instalar y esperar
    "<left><wait300ms><enter><wait1m45s>${local.slowdown}",
    # completar instalación / confirmar
    "<down><enter><wait50s>${local.slowdown}",
    # si regresa al live, entra como root/opnsense
    "root<enter>opnsense<enter><wait1s>",
    "8<enter><wait3s>",              # 8) Shell
    "dhclient vtnet0<enter><wait3>", # IP por DHCP en WAN
    "${local.fetch_cfg}<enter><wait2s>",
    "echo 'PasswordAuthentication yes' >> /usr/local/etc/ssh/sshd_config<enter>",
    "service openssh onestart<enter><wait2s>",
    # reiniciar al sistema instalado
    "exit<enter><wait300ms>6<enter><wait300ms>y<enter>",
  ]
}

source "proxmox-iso" "opnsense" {
  proxmox_url              = var.proxmox_url
  insecure_skip_tls_verify = true
  username                 = var.proxmox_username
  token                    = var.proxmox_token

  node    = var.proxmox_node
  vm_id   = var.vm_id
  vm_name = var.vm_name

  memory     = 4096
  cores      = 2
  sockets    = 1
  qemu_agent = false

  disks {
    type         = "scsi"
    storage_pool = var.storage_pool
    disk_size    = "16G"
  }

  network_adapters {
    model  = "virtio"
    bridge = var.lan_bridge
  }
  network_adapters {
    model       = "virtio"
    bridge      = var.wan_bridge
    mac_address = "00:50:56:00:A9:D6"

  }

  boot_iso {
    type         = "scsi"
    iso_file     = "local:iso/OPNsense-25.7-dvd-amd64.iso"
    iso_checksum = "none" # pon el checksum real si quieres validarlo
    unmount      = true
  }

  boot_wait    = "10s"
  boot_command = local.boot_steps

  # HTTP embebido de Packer para servir config.xml
  http_directory = "http"

  communicator = "ssh"
  ssh_username = "root"
  ssh_password = "opnsense"
  ssh_timeout  = "30m"
}

build {
  sources = ["source.proxmox-iso.opnsense"]

  # Ya en el sistema instalado (no el live), vuelve a traer config.xml y aplica
  provisioner "shell" {
    inline = [
      "fetch -o /conf/config.xml http://{{ .HTTPIP }}:{{ .HTTPPort }}/config.xml",
      "configctl interface reconfigure || true",
      "configctl filter reload || true",
      # deja SSH habilitado si quieres seguir usando provisioners en clones
      "sed -i '' -e 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config || true",
      "service sshd restart || true"
    ]
  }
}