#!/bin/bash
set -e

# Esperar a que termine cualquier proceso de yum/cloud-init que tenga el lock
MAX_RETRIES=30
RETRY=0
while lsof /var/run/yum.pid >/dev/null 2>&1 || pgrep -x yum >/dev/null 2>&1; do
  sleep 2
  RETRY=$((RETRY+1))
  if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
    echo "Timeout waiting for yum lock"
    break
  fi
done

# Instalar nginx en Amazon Linux 2 usando amazon-linux-extras (recomendado)
if command -v amazon-linux-extras >/dev/null 2>&1; then
  amazon-linux-extras install -y nginx1
else
  yum install -y nginx || true
fi

systemctl enable nginx || true
systemctl start nginx || true

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds:21600" || true)
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "n/a")
LOCAL_IPV4=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 || hostname -I | awk '{print $1}')
PUBLIC_IPV4=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || echo "n/a")
HOSTNAME=$(hostname -f || hostname)

# Variables inyectadas por Terraform (serán sustituidas con replace())
NAMESPACE="__NAMESPACE__"
SERVICES="__SERVICES__"
RESOLVER="__RESOLVER__"

# Generar index.html dinámico con subdominios
mkdir -p /usr/share/nginx/html
cat > /usr/share/nginx/html/index.html <<HTML_EOF
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>AWS EC2 Instance - Nginx Load Balancer</title>
    <style>
      body{font-family:Arial,Helvetica,sans-serif;margin:2rem; line-height:1.6}
      .status-ok { color: green; }
      .status-warning { color: orange; }
      .status-error { color: red; }
      .service-card {
        background: #f5f5f5;
        padding: 1rem;
        margin: 1rem 0;
        border-radius: 8px;
        border-left: 4px solid #007cba;
      }
      .url {
        background: #e9ecef;
        padding: 0.5rem;
        border-radius: 4px;
        font-family: monospace;
        margin: 0.5rem 0;
      }
      a { color: #007cba; text-decoration: none; }
      a:hover { text-decoration: underline; }
    </style>
  </head>
  <body>
    <h1>AWS EC2 Instance - Reverse Proxy</h1>
    <p>Información de la máquina que sirve este proxy NGINX:</p>
    <ul>
      <li><strong>Hostname:</strong> $HOSTNAME</li>
      <li><strong>Instance ID:</strong> $INSTANCE_ID</li>
      <li><strong>Private IP:</strong> $LOCAL_IPV4</li>
      <li><strong>Public IP:</strong> $PUBLIC_IPV4</li>
    </ul>

    <h2>Servicios Disponibles:</h2>
HTML_EOF

for SVC in $SERVICES; do
  [ -z "$SVC" ] && continue
  if [ "$SVC" = "mariadb" ] || [ "$SVC" = "postgresql" ]; then
    continue
  fi
  
cat >> /usr/share/nginx/html/index.html <<HTML_EOF
    <div class="service-card">
      <h3>${SVC^}</h3>
      <div class="url">http://$SVC.$PUBLIC_IPV4.nip.io</div>
      <a href="http://$SVC.$PUBLIC_IPV4.nip.io" target="_blank">Abrir ${SVC^}</a>
    </div>
HTML_EOF
done

cat >> /usr/share/nginx/html/index.html <<HTML_EOF
  </body>
</html>
HTML_EOF

# Crear página de error 50x
cat > /usr/share/nginx/html/50x.html <<HTML_EOF
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Error del Servidor</title>
    <style>body{font-family:Arial,Helvetica,sans-serif;margin:2rem;text-align:center}</style>
  </head>
  <body>
    <h1>Error del Servidor</h1>
    <p>El servicio no está disponible temporalmente.</p>
    <p><a href="/">Volver al inicio</a></p>
  </body>
</html>
HTML_EOF

# Generar configuración de NGINX SIMPLE Y FUNCIONAL
NGINX_CONF="/etc/nginx/conf.d/reverse-proxy.conf"

# Configuración base
cat > "$NGINX_CONF" <<NGX
# Server block para WordPress
server {
    listen 80;
    server_name wordpress.$PUBLIC_IPV4.nip.io;

    location / {
        proxy_pass http://wordpress.$NAMESPACE:8080;

        # Headers básicos y limpios
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;

        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Buffers
        proxy_buffering on;
        proxy_buffer_size 16k;
        proxy_buffers 4 16k;
    }
}

# Server block para la página de inicio
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;

    location / {
        try_files \$uri /index.html =404;
    }
    
    # Manejo de errores
    error_page 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
        internal;
    }
}
NGX

# Crear directorio de logs si no existe
mkdir -p /var/log/nginx

# Validar y recargar nginx
if nginx -t >/tmp/nginx-test.log 2>&1; then
  echo "✅ nginx: configuración OK"
  systemctl restart nginx || true
  echo "✅ nginx reiniciado correctamente"
else
  echo "❌ nginx: configuración FAILED"
  cat /tmp/nginx-test.log
  exit 1
fi

# Información final
echo "=========================================="
echo "🚀 NGINX Reverse Proxy Configuration Complete"
echo "=========================================="
echo "Instance: $INSTANCE_ID ($HOSTNAME)"
echo "Private IP: $LOCAL_IPV4"
echo "Public IP: $PUBLIC_IPV4"
echo "WordPress URL: http://wordpress.$PUBLIC_IPV4.nip.io"
echo "Dashboard URL: http://$PUBLIC_IPV4"
echo "=========================================="