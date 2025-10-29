# NGINX Reverse Proxy / Load Balancer (Terraform + User Data)

Descripción
-----------
Este repositorio despliega una instancia EC2 con NGINX configurado como reverse proxy / load balancer usando Terraform y scripts de user-data. Incluye integración con Service Discovery para resolver upstreams dinámicos.

Estructura relevante
- Infra como código: [main.tf](main.tf), [provider.tf](provider.tf), [variables.tf](variables.tf), [outputs.tf](outputs.tf)
- Módulos: [modules/services_discovery/private/main.tf](modules/services_discovery/private/main.tf), [modules/services_discovery/private/outputs.tf](modules/services_discovery/private/outputs.tf)
- Plantillas NGINX y user-data: [templates/nginx.conf.tpl](templates/nginx.conf.tpl), [templates/user-data.sh.tpl](templates/user-data.sh.tpl)
- Scripts de configuración y monitoreo: [scripts/setup-nginx.sh](scripts/setup-nginx.sh)
- Estado local / módulos: [.terraform/modules/modules.json](.terraform/modules/modules.json)

Despliegue rápido
1. Inicializar Terraform:
   - terraform init
2. Previsualizar:
   - terraform plan -out=tfplan --var-file="file.tfvars"
3. Aplicar:
   - terraform apply tfplan

Valores y salidas útiles
- IP pública del NGINX: recurso [`aws_eip.nginx`](main.tf) — salida en [outputs.tf](outputs.tf) como `nginx_public_ip`.
- ID de la instancia: recurso [`aws_instance.nginx_proxy`](main.tf) — salida en [outputs.tf](outputs.tf) como `nginx_instance_id`.
- Namespace de Service Discovery: salida [`module.services_discovery.namespace_id`](outputs.tf).

Notas operativas
- El template principal de NGINX usa el resolver de VPC (169.254.169.253) para Service Discovery — ver [templates/nginx.conf.tpl](templates/nginx.conf.tpl).
- SSH: la clave generada se guarda localmente como archivo `${aws_key_pair.nginx.key_name}.pem` — consulta [main.tf](main.tf) y [outputs.tf](outputs.tf) para el comando de conexión.
- El script de setup y health checks está en [scripts/setup-nginx.sh](scripts/setup-nginx.sh). Revisa logs en /var/log/nginx-setup.log y /var/log/nginx-lb-install.log.

Buenas prácticas
- No subir claves privadas ni tfstate al repo.
- Revisar y actualizar `variables.tf` y `provider.tf` antes de ejecutar en producción.

Licencia
--------
MIT