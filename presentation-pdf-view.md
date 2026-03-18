---
title: Infrastructure Kubernetes K3s
sub_title: Projet DevOps B3
author: DevOps Team
---

<!-- font_size: 2 -->

Infrastructure Kubernetes K3s
===

# Infrastructure Kubernetes K3s

- Architecture du Cluster
- IaC / Provisionning
- Arborescence du Projet
- GitOps / Flux de Déploiement
- Applications installées
- Gestion des Secrets

<!-- end_slide -->

<!-- font_size: 2 -->

# Architecture du Cluster

Le cluster repose sur **K3s** avec des nœuds sous Ubuntu 24.04 LTS.

| Node       | Rôle            | Système          |
|------------|-----------------|------------------|
| **k3s-cp**     | Control-Plane   | Ubuntu 24.04 LTS |
| **k3s-wk-01**  | Worker          | Ubuntu 24.04 LTS |
| **k3s-wk-02**  | Worker          | Ubuntu 24.04 LTS |

---

![image:width:100%](media/nodes.png)

<!-- end_slide -->

<!-- font_size: 2 -->

# IaC

 - Pour le déploiement des machines du cluster nous utilisons terraform avec le provider Proxmox
```
└── terraform2
    ├── main.tf
    ├── terraform.tfvars
    └── variables.tf
```

- Variable de configuration du cluster

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

<!-- end_slide -->

<!-- font_size: 2 -->

- Utilisation des variables

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

- Configuration des machines du cluster 
```terraform
vms = {
  "master-k3s" = {
    name           = "vm-master"
    memory         = 10240
    cores          = 5
    network_bridge = "vmbr0"
  }
  ...
}
```

### Documentation complète sur Github

<!-- end_slide -->

<!-- font_size: 2 -->

# Arborescence du Projet

Une structure claire pour la gestion Helm et ArgoCD :

* **helm-apps/** : Contient toutes les définitions d'applications.
* **media/** : Assets et schémas d'architecture.
* **flake.nix** : Environnement de développement reproductible.

```bash
Devops-B3/
├── helm-apps/
│   ├── root-app.yaml          # Application "App of Apps" racine
│   ├── manifest-app/
│   │   ├── application.yaml   # ArgoCD Application
│   │   └── manifests.yaml    # Manifests Kubernetes (Deployment, Service, PVC, IngressRoute)
│   └── helm-app/
│       ├── application.yaml   # ArgoCD Application via helm chart
│       └── values.yaml       # Valeurs Helm
├── flake.nix # configuration nix
└── README.md
```

<!-- end_slide -->

<!-- font_size: 2 -->

# GitOps avec ArgoCD

Nous utilisons le pattern **"App of Apps"**.

1. **L'Application Racine** (`root-app.yaml`) surveille le dossier `helm-apps/`.
2. Elle déploie automatiquement toute nouvelle application définie.

![image:width:100%](media/argocd.png)

<!-- end_slide -->

<!-- font_size: 2 -->

# Flux de Déploiement

Le cycle de vie d'une modification :

1. **Push** sur la branche `main`.
2. **Détection** automatique par ArgoCD.
3. **Synchronisation** des manifests sur le cluster.
4. **Vérification** de l'état de santé des ressources.

![](media/argonaut.png)

<!-- end_slide -->

<!-- font_size: 2 -->

# Applications Déployées

Un écosystème complet de services :

* **Streaming & Media** : Jellyfin, Jellyseerr, Jellystat.
* **Automation** : n8n.
* **Observabilité** : Prometheus & Grafana.

![](media/k9s.png)

<!-- end_slide -->

<!-- font_size: 2 -->

# Gestion des Secrets

Approche actuelle : **Secrets Opaques manuels**.

```bash
kubectl create secret generic jellystat-secrets \
  --namespace jellyfin \
  --from-literal=POSTGRES_PASSWORD='***' \
  --from-literal=JWT_SECRET='***'
```

*Note : Des solutions comme HashiCorp Vault ou SOPS sont envisagées pour le futur.*

<!-- end_slide -->

<!-- font_size: 2 -->

# Outillage : Nix

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

Utilisation de **Nix Flakes** pour garantir que tous les intervenants utilisent les mêmes versions des outils :

* `kubectl`
* `helm`
* `argocd`
* ...

Fini le "ça marche sur ma machine" !

<!-- column: 1 -->

![image:width:70%](media/nix.png)

<!-- reset_layout -->

<!-- end_slide -->

<!-- font_size: 2 -->

Merci de votre attention !
===

# Des questions ?

# Sources
* Sources : [GitHub Repo]
* Documentation : [Kubernetes / ArgoCD / Helm]
* Tout les outils utilisés sont open-source (voir README)