# Proxmox VM Setup with Terraform

## VM Setup Script

```bash
chmod +x scripts/vm_setup.sh
```

## Init Terraform

puis initialiser le provider 

```bash
terraform init
```

puis checker la validité de la configuration

```bash
terraform plan
```

puis appliquer la configuration

```bash
terraform apply
```

## Destroy Terraform

Pour détruire la configuration

```bash
terraform destroy
```
