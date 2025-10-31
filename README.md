# NGINX Reverse Proxy / Load Balancer (Terraform + User Data)

## Descripción
Este repositorio despliega una instancia EC2 con NGINX configurado como reverse proxy / load balancer usando Terraform y scripts de user-data. Incluye integración con Service Discovery para resolver upstreams dinámicos.


## Despliegue rápido
1. Inicializar Terraform:
   - terraform init
2. Previsualizar:
   - terraform plan -out=tfplan --var-file="file.tfvars"
3. Aplicar:
   - terraform apply tfplan


## Pruebas
```bash
# Básicos
whoami
hostname
uname -a

# Estado de NGINX y configuración
sudo systemctl status nginx
sudo nginx -t
sudo cat /etc/nginx/conf.d/reverse-proxy.conf
sudo tail -n 200 /var/log/nginx/error.log
sudo tail -n 200 /var/log/nginx/access.log

# Ver puertos escuchando
sudo ss -tulpn | grep nginx || sudo ss -tulpn
```