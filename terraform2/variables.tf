# Configuration Proxmox
variable "pm_api_url" {
  description = "URL de l'API Proxmox"
  type        = string
  default     = "https://192.168.1.34:8006/api2/json"
}

variable "pm_api_token_id" {
  description = "ID du token Proxmox au format user@realm!tokenid"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Secret du token Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_host" {
  description = "Adresse IP du serveur Proxmox pour SSH"
  type        = string
  default     = "192.168.1.34"
}

variable "target_node" {
  description = "Nom du noeud Proxmox où créer la VM"
  type        = string
  default     = "pve"
}

# Configuration Template
variable "template_name" {
  description = "Nom du template Cloud-Init à cloner"
  type        = string
  default     = "ubuntu-22.04-cloudinit"
}

variable "storage" {
  description = "Nom du stockage pour les disques"
  type        = string
  default     = "local-lvm"
}

# Configuration réseau
variable "network_bridge" {
  description = "Bridge réseau par défaut à utiliser"
  type        = string
  default     = "vmbr0"
}

# Configuration Cloud-Init
variable "vm_user" {
  description = "Utilisateur par défaut créé par Cloud-Init"
  type        = string
  default     = "ubuntu"
}

variable "vm_password" {
  description = "Mot de passe de l'utilisateur"
  type        = string
  sensitive   = true
  default     = "root"
}

variable "vms" {
  description = "Map des VMs à créer"
  type = map(object({
    name           = string
    memory         = number
    cores          = number
    network_bridge = optional(string)
  }))
}
