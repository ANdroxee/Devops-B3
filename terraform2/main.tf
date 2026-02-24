terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "linux_vm" {
  for_each = var.vms

  name        = each.value.name
  target_node = var.target_node
  clone       = var.template_name
  full_clone  = true

  os_type = "cloud-init"
  scsihw  = "virtio-scsi-pci"

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }

  memory = each.value.memory

  vga {
    type = "std"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = coalesce(each.value.network_bridge, var.network_bridge)
  }

  ipconfig0    = "ip=dhcp"
  ciuser       = var.vm_user
  cipassword   = var.vm_password

  automatic_reboot = false

  lifecycle {
    ignore_changes = all
  }

  provisioner "local-exec" {
    command = <<-EOT
    ssh -i ~/.ssh/proxmox_tf root@${var.proxmox_host} << 'EOF'
    set -e
    VMID=${self.vmid}
    VM_NAME="${each.value.name}"
    STORAGE="${var.storage}"
    NETWORK_BRIDGE="${coalesce(each.value.network_bridge, var.network_bridge)}"

    echo "Configuring VM $VMID ($VM_NAME)"

    echo "Stopping VM..."
    qm stop $VMID 2>/dev/null || true
    sleep 3

    # Attacher le disque principal
    if ! qm config $VMID | grep -q "^scsi0:"; then
      echo "Attaching main disk..."
      DISK=$(qm config $VMID | grep "^unused0:" | awk '{print $2}')
      if [ -n "$DISK" ]; then
        qm set $VMID --scsi0 $DISK
        qm set $VMID --delete unused0 2>/dev/null || true
      fi
    fi

    qm set $VMID --vga std

    # Cloud-Init
    mkdir -p /var/lib/vz/snippets
    cat > /var/lib/vz/snippets/cloud-init-fr-$VMID.yml << CLOUD
#cloud-config
locale: fr_FR.UTF-8
timezone: Europe/Paris
keyboard:
  layout: fr
  variant: azerty

users:
  - name: ubuntu
    groups: [sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    lock_passwd: false
ssh_pwauth: true
disable_root: false

chpasswd:
  expire: false
  list: |
    ubuntu:${var.vm_password}

package_update: true
packages:
  - qemu-guest-agent
  - openssh-server

runcmd:
  - localectl set-keymap fr
  - timedatectl set-timezone Europe/Paris
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart ssh
CLOUD

    # Ajouter disque Cloud-Init
    if ! qm config $VMID | grep -q "ide2:.*cloudinit"; then
      qm set $VMID --ide2 $STORAGE:cloudinit
    fi

    qm set $VMID --cicustom "user=local:snippets/cloud-init-fr-$VMID.yml"
    qm cloudinit update $VMID

    qm start $VMID

    echo "VM $VMID ($VM_NAME) configured successfully"
EOF
    EOT
  }
}

resource "null_resource" "cleanup_cloudinit" {
  for_each   = var.vms
  depends_on = [proxmox_vm_qemu.linux_vm]

  triggers = {
    vm_id        = proxmox_vm_qemu.linux_vm[each.key].vmid
    proxmox_host = var.proxmox_host
  }

  provisioner "local-exec" {
    when    = destroy
    command = "ssh root@${self.triggers.proxmox_host} 'rm -f /var/lib/vz/snippets/cloud-init-fr-${self.triggers.vm_id}.yml' 2>/dev/null || true"
  }
}

output "vm_ids" {
  value = {
    for k, vm in proxmox_vm_qemu.linux_vm : k => vm.vmid
  }
}

output "vm_names" {
  value = {
    for k, vm in proxmox_vm_qemu.linux_vm : k => vm.name
  }
}

output "vm_network_bridges" {
  value = {
    for k, vm in var.vms : k => coalesce(vm.network_bridge, var.network_bridge)
  }
  description = "Bridge réseau utilisé par chaque VM"
}

output "vm_info" {
  sensitive = true
  value = <<-EOT
    ═══════════════════════════════════════════════════════
    VMs créées avec succès !
    ═══════════════════════════════════════════════════════

    ${join("\n    ", [for k, vm in proxmox_vm_qemu.linux_vm : "✓ ${vm.name} (ID: ${vm.vmid}) - Bridge: ${coalesce(var.vms[k].network_bridge, var.network_bridge)}"])}

  EOT
}
