# Déploiement automatisé d'un cluster K3s avec Ansible

## Description

Ce playbook Ansible automatise le déploiement d'un cluster Kubernetes K3s composé d'un nœud maître et de nœuds workers. Il gère l'installation, la configuration réseau et l'agrégation du cluster de manière entièrement automatisée.

## Architecture

- **Master** : Nœud de contrôle du cluster K3s (API server, etcd)
- **Workers** : Nœuds agents rejoignant le cluster via le token du master

## Prérequis

- Ansible installé sur votre machine de contrôle
- Accès SSH aux serveurs cibles
- Fichier d'inventaire Ansible configuré avec les groupes `master` et `workers`
- Au minimum : 1 nœud master + 1 nœud worker (ou plus)

## Configuration de l'inventaire

Créez un fichier `inventory.yml` ou `hosts.ini` :

```ini
[master]
k3s-master ansible_host=192.168.1.10 ansible_user=ubuntu

[workers]
k3s-worker1 ansible_host=192.168.1.11 ansible_user=ubuntu
k3s-worker2 ansible_host=192.168.1.12 ansible_user=ubuntu
```

## Commandes de lancement

### 1. Lancer le déploiement complet

```bash
ansible-playbook -i inventory.yml playbook.yml
```

### 2. Spécifier la version de K3s

```bash
ansible-playbook -i inventory.yml playbook.yml -e k3s_version=v1.28.0
```

Par défaut, la version la plus récente est installée.

### 3. Exécuter uniquement le master

```bash
ansible-playbook -i inventory.yml playbook.yml --tags "master" -l master
```

Ou plus simplement :

```bash
ansible-playbook -i inventory.yml playbook.yml -e "ansible_limit=master"
```

### 4. Exécuter uniquement les workers

```bash
ansible-playbook -i inventory.yml playbook.yml -l workers
```

### 5. Mode verbeux (pour le débogage)

```bash
ansible-playbook -i inventory.yml playbook.yml -vv
```

## Étapes exécutées

### Sur le Master :
1. Mise à jour des paquets système
2. Installation des dépendances (curl, apt-transport-https)
3. Installation du serveur K3s
4. Configuration de l'URL d'accès au cluster
5. Récupération du token de cluster

### Sur les Workers :
1. Mise à jour des paquets système
2. Installation des dépendances
3. Récupération du token depuis le master
4. Jonction au cluster K3s avec le token

## Vérification après déploiement

Une fois le playbook terminé, vérifiez l'état du cluster :

```bash
# Sur le master
ssh ubuntu@192.168.1.10

# Voir tous les nœuds
sudo k3s kubectl get nodes

# Voir l'état du cluster
sudo k3s kubectl cluster-info

# Voir les pods système
sudo k3s kubectl get pods -A
```

## Troubleshooting

**Les workers ne rejoignent pas le cluster :**
- Vérifiez la connectivité réseau entre master et workers (port 6443)
- Vérifiez que le token est correct : `sudo cat /var/lib/rancher/k3s/server/node-token` sur le master
- Consultez les logs : `sudo journalctl -u k3s-agent -n 50`

**Problème de résolution de nom :**
- Assurez-vous que `ansible_host` utilise une adresse IP accessible
- Vérifiez que le firewall autorise le port 6443

## Notes importantes

- Les variables `k3s_token` et `k3s_server_url` sont automatiquement partagées entre master et workers
- Le playbook idempotent (l'exécuter plusieurs fois ne causera pas de problèmes)
- Les certificats K3s sont auto-signés par défaut
