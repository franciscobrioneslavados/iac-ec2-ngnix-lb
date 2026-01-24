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

Outputs:

```bash
nginx_instance_id = "i-0e4a8dcbe8f72277e"
nginx_public_ip = "44.212.247.78"
nginx_security_group_id = "sg-03e9b677a6e3f6312"
ssh_connection = "ssh -i 'development-nginx-reverse-proxy-key.pem' ec2-user@ec2-44-212-247-78.compute-1.amazonaws.com"
```

# Comandos para que ejecutes en tu instancia:

```bash
ssh -i 'development-nginx-reverse-proxy-key.pem' ec2-user@3.223.132.68
```

## Pruebas

````bash
# Básicos
whoami
hostname
uname -a

# Estado de NGINX y configuración
sudo systemctl status nginx
sudo nginx -t
sudo cat /etc/nginx/conf.d/01-services-map.conf
sudo cat /var/log/cloud-init-output.log
sudo tail -n 200 /var/log/nginx/error.log
sudo tail -n 200 /var/log/nginx/access.log


## Si la instancia cambia ejecutar

```bash
ssh-keygen -R ec2-34-235-186-62.compute-1.amazonaws.com
````

====================================================================================================

## Pruebas Parte 1

🔹 IP pública correcta
curl -s http://169.254.169.254/latest/meta-data/public-ipv4

```bash
34.198.197.254
```

dig franciscobrioneslavados.com +short

```bash
34.198.197.254
```

🔹 Nginx vivo
sudo systemctl status nginx --no-pager

```bash
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2026-01-22 23:31:44 UTC; 7min ago
       Docs: man:nginx(8)
   Main PID: 2551 (nginx)
      Tasks: 2 (limit: 1125)
     Memory: 3.7M
        CPU: 43ms
     CGroup: /system.slice/nginx.service
             ├─2551 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             └─2552 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""

Jan 22 23:31:44 ip-10-0-0-49 systemd[1]: Starting A high performance web server and a reverse proxy server...
Jan 22 23:31:44 ip-10-0-0-49 systemd[1]: Started A high performance web server and a reverse proxy server.
```

🔹 Puertos abiertos
sudo ss -lntp | grep nginx

```bash
LISTEN 0      511          0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=2552,fd=6),("nginx",pid=2551,fd=6))
LISTEN 0      511          0.0.0.0:443       0.0.0.0:*    users:(("nginx",pid=2552,fd=7),("nginx",pid=2551,fd=7))
```

🔹 HTTPS local
curl -kI https://localhost

```bash
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Thu, 22 Jan 2026 23:39:17 GMT
Content-Type: text/html
Content-Length: 900
Last-Modified: Thu, 22 Jan 2026 23:31:43 GMT
Connection: keep-alive
ETag: "6972b35f-384"
Accept-Ranges: bytes
```

✔ 200 OK
🔹 HTTPS público
curl -kI https://franciscobrioneslavados.com
✔ 200 OK
🧾 3. Certificados
🔹 Ver cert usado por Nginx
openssl s_client -connect localhost:443 -servername franciscobrioneslavados.com </dev/null | openssl x509 -noout -subject -issuer

```bash
depth=0 C = CL, ST = RM, L = Santiago, O = Edge, CN = franciscobrioneslavados.com
verify error:num=18:self-signed certificate
verify return:1
depth=0 C = CL, ST = RM, L = Santiago, O = Edge, CN = franciscobrioneslavados.com
verify return:1
DONE
subject=C = CL, ST = RM, L = Santiago, O = Edge, CN = franciscobrioneslavados.com
issuer=C = CL, ST = RM, L = Santiago, O = Edge, CN = franciscobrioneslavados.com
```

🔹 Firewall OS (Ubuntu)
sudo iptables -L -n

```bash
Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination
```
