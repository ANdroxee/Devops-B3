# IaC

 - Pour le déploiement des machines du cluster nous utilisons terraform avec le provider Proxmox
```
└── terraform2
    ├── main.tf
    ├── terraform.tfvars
    └── variables.tf
```

Variable de configuration du cluster


```terraform
variable "pm_api_url" {
  description = "URL de l'API Proxmox"
  type        = string
  default     = "https://IP_PROXMOX:8006/api2/json"
}

variable "pm_api_token_id" {
  description = "ID du token Proxmox au format user@realm!tokenid"
  type        = string
  sensitive   = true
}
```

Configuration des machines du cluster 
```terraform
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
```

Utilisation des variables
```terraform
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
```

### Provisionning 

- Pour le provisionning des machines nous utilisons ansible pour l'installation du cluster 

```
├── cluster-k3s
│   ├── all.yml
│   ├── inventory
│   │   └── hosts.ini
│   ├── playbook.yml
│   └── README.md
└── README.md
```

```yml
k3s_version: "v1.30.1+k3s1"
k3s_server_url: "https://{{ hostvars['master']['ansible_host'] }}:6443"
k3s_token_file: "/var/lib/rancher/k3s/server/node-token"
```

Phase d'installation du master k3s

```yml
- name: Installation du cluster K3s - Master
  hosts: master
  become: true
  vars:
      k3s_token_file: /var/lib/rancher/k3s/server/node-token
  tasks:
      - name: Mettre à jour les paquets
        ansible.builtin.apt:
            update_cache: yes
            upgrade: yes

      - name: Installer les dépendances
        ansible.builtin.apt:
            name:
                - curl
                - apt-transport-https
            state: present

      - name: Installer le serveur K3s
        ansible.builtin.shell: |
            curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION={{ k3s_version }} sh -
        args:
            creates: /usr/local/bin/k3s

      - name: Définir l'URL du serveur K3s
        ansible.builtin.set_fact:
            k3s_server_url: "https://{{ ansible_host }}:6443"

      - name: Récupérer le token du cluster
        ansible.builtin.slurp:
            src: "{{ k3s_token_file }}"
        register: k3s_token_raw

      - name: Définir le token en variable
        ansible.builtin.set_fact:
            k3s_token: "{{ k3s_token_raw.content | b64decode | trim }}"
```

Phase d'installation des workers du cluster

```yml
- name: Installation du cluster K3s - Workers
  hosts: workers
  become: true
  vars:
      k3s_token: "{{ hostvars[groups['master'][0]]['k3s_token'] }}"
      k3s_server_url: "{{ hostvars[groups['master'][0]]['k3s_server_url'] }}"
  tasks:
      - name: Mettre à jour les paquets
        ansible.builtin.apt:
            update_cache: yes
            upgrade: yes

      - name: Installer les dépendances
        ansible.builtin.apt:
            name:
                - curl
                - apt-transport-https
            state: present

      - name: Joindre le nœud au cluster K3s
        ansible.builtin.shell: |
            curl -sfL https://get.k3s.io | K3S_URL={{ k3s_server_url }} K3S_TOKEN={{ k3s_token }} INSTALL_K3S_VERSION={{ k3s_version }} sh -
        args:
            creates: /usr/local/bin/k3s-agent
```