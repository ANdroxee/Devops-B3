# Credentials Proxmox
pm_api_token_id     = "terraform-prov@pve!terraform"
pm_api_token_secret = ""

# Serveur Proxmox
proxmox_host = "10.111.63.100"

# Template
template_name = "ubuntu-22.04-cloudinit"

# Configuration réseau par défaut
network_bridge = "vmbr0"

# Cloud-Init
vm_user     = "ubuntu"
vm_password = "root"

vms = {
  "master-k3s" = {
    name           = "vm-master"
    memory         = 10240
    cores          = 5
    network_bridge = "vmbr0"
  }
  "slave-1-k3s" = {
    name           = "vm-worker-1"
    memory         = 10240
    cores          = 5
    network_bridge = "vmbr0"
  }
  "slave-2-k3s" = {
    name           = "vm-worker-2"
    memory         = 10240
    cores          = 5
    network_bridge = "vmbr0"
  }
}
