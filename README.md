# Infrastructure Kubernetes K3s - Projet DevOps B3

## Architecture du Cluster

---

### IaC

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

Pour le provisionning des machines nous utilisons ansible pour l'installation du cluster 

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

---

### Nodes

![nodes](/media/nodes.png)

| Node       | Rôle            | Système          |
|------------|-----------------|------------------|
| k3s-cp     | Control-Plane   | Ubuntu 24.04 LTS |
| k3s-wk-01  | Worker          | Ubuntu 24.04 LTS |
| k3s-wk-02  | Worker          | Ubuntu 24.04 LTS |

---

## Arborescence du Projet

```
Devops-B3/
├── helm-apps/
│   ├── root-app.yaml          # Application "App of Apps" racine
│   ├── jellyseerr/
│   │   ├── application.yaml   # ArgoCD Application pour Jellyseerr
│   │   └── manifests.yaml    # Manifests Kubernetes (Deployment, Service, PVC, IngressRoute)
│   ├── jellystat/
│   │   ├── application.yaml  # ArgoCD Application pour Jellystat
│   │   └── manifests.yaml    # Manifests (PostgreSQL, Jellystat, Exporter, ServiceMonitor)
│   ├── monitoring/
│   │   ├── application.yaml  # ArgoCD Application pour la stack monitoring
│   │   └── values.yaml       # Valeurs Helm pour kube-prometheus-stack
│   └── n8n/
│       ├── application.yaml   # ArgoCD Application pour n8n
│       └── values.yaml       # Valeurs Helm pour n8n
└── README.md
```

---

## GitOps avec ArgoCD

![argocd](media/argocd.png)

### Pattern "App of Apps"

Le projet utilise le pattern **App of Apps** recommandé par [ArgoCD](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/).

#### Application Racine (root-app.yaml)

L'application racine `root-apps` est déployée dans le namespace `argocd` et scanne le répertoire `helm-apps/` (situé à la racine du repo Github) à la recherche de tous les fichiers `application.yaml`.

file [root-app.yaml](helm-apps/root-app.yaml)

#### Applications

Chaque application déployée possède un sous dossier dédié dans `helm-apps/` avec

### Flux de Déploiement

1. **Déclencheur** : Push sur la branche `main` du dépôt Git
2. **Détection** : ArgoCD détecte les changements via le dépôt Git (ou sync manuel sur argo)
3. **Synchronisation** : ArgoCD applique les manifests sur le cluster
4. **Vérification** : Les ressources sont vérifiées et passent à l'état `Synced`

---

## Applications

| Application    | Namespace  | Logo                                   |
|----------------|------------|----------------------------------------|
| Jellyfin       | jellyfin   | <img src="media/jellyfin.svg" alt="Jellyfin Logo" width="52" height="52"> |
| Jellyseerr     | jellyfin   | <img src="media/jellyseerr.png" alt="Jellyseerr Logo" width="52" height="52"> |
| Jellystat      | jellyfin   | <img src="media/jellystat.png" alt="Jellystat Logo" width="52" height="52"> |
| n8n            | n8n        | <img src="media/n8n.png" alt="n8n Logo" width="52" height="32"> |
| Grafana        | monitoring | <img src="media/grafana.png" alt="Grafana Logo" width="52" height="52"> |
| Prometheus     | monitoring | <img src="media/prometheus.png" alt="Prometheus Logo" width="52" height="52"> |

![k9s](media/k9s.png)

> [!NOTE]
> Il y a d'autres services de déployés mais ce sont de services secondaires (alertmanager, jellyfin-exporter, etc). Vous noterrez aussi que jellyfin n'a pas été déployé via ArgoCD.

![argonaut](media/argonaut.png)

---

## Gestion des Secrets

Pour la gestion des secrets, nous avons fait au plus simple pour commencer avec juste une création manuelle (type `Opaque`).

Exemple :

```bash
kubectl create secret generic jellystat-secrets \
  --namespace jellyfin \
  --from-literal=POSTGRES_PASSWORD='motdepasse-securise' \
  --from-literal=JWT_SECRET='jwt-secret-aleatoire'
```

Voir documentation [ici](https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-kubectl/).

Il y a biensur des alternatives plus robustes pour la gestion des secrets (HashiCorp Vault, Bitwarden, Sops, etc) mais cela sort du scope de ce projet + manque de temps.

## Nix

On utilise une configuration Nix pour gérer les tools, histoire d'avoir tous les mêmes ([flake](./flake.nix) peut-être overkill vu que l'on a pas de dépendances à lock mais tant qu'à faire).

## Sources

- [All workflow](/media/media-devops-b3-project.excalidraw) - excalidraw format
- [ArgoCD Workflow](https://medium.com/@kittipat_1413/introduction-to-gitops-with-argocd-foundations-and-architecture-8a4d44070ba3)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/en/stable/)
- [Nix Flake](https://github.com/NixOS/templates)

Charts utilisés :
- [n8n](https://github.com/8gears/n8n-helm-chart)
- [prometheus](https://github.com/prometheus-community/helm-charts)
- [jellyfin](https://github.com/jellyfin/jellyfin)
- [jellyseerr](https://github.com/seerr-team/seerr)
- [jellystat](https://github.com/CyferShepard/Jellystat)
- [n8n](https://github.com/n8n-io/n8n)
- [grafana](https://github.com/grafana/grafana)
- [prometheus](https://github.com/prometheus/prometheus)
- [argocd](https://github.com/argoproj/argo-cd)
