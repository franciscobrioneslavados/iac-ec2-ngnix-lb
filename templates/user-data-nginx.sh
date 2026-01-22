#!/bin/bash
set -e

############################################
# WAIT FOR YUM LOCK
############################################
MAX_RETRIES=30
RETRY=0
while lsof /var/run/yum.pid >/dev/null 2>&1 || pgrep -x yum >/dev/null 2>&1; do
  sleep 2
  RETRY=$((RETRY+1))
  [ "$RETRY" -ge "$MAX_RETRIES" ] && break
done

############################################
# INSTALL PACKAGES
############################################
if command -v amazon-linux-extras >/dev/null 2>&1; then
  amazon-linux-extras install -y nginx1 epel
else
  yum install -y nginx epel-release || true
fi

# Install SSL and system packages
yum install -y openssl11 openssl11-devel

# Install certbot (fallback to self-signed if fails)
yum install -y certbot || true

# Install certbot nginx plugin
pip3 install certbot-nginx || true

systemctl enable nginx
systemctl start nginx

############################################
# METADATA (IMDSv2)
############################################
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds:21600" || true)

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id || echo "n/a")

LOCAL_IPV4=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

PUBLIC_IPV4=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

HOSTNAME=$(hostname -f || hostname)

############################################
# TERRAFORM VARIABLES
############################################
ENVIRONMENT="${environment}"
DOMAIN_NAME="${domain_name}"
NAMESPACE="${namespace}"
SERVICES="${services}"
RESOLVER="${resolver}"

############################################
# HTML DASHBOARD
############################################
mkdir -p /usr/share/nginx/html

cat > /usr/share/nginx/html/index.html <<HTML
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Nginx ECS Edge</title>
<style>
body{font-family:Arial;margin:2rem}
.card{background:#f5f5f5;padding:1rem;margin:1rem 0;border-radius:8px}
.code{font-family:monospace;background:#eee;padding:.3rem}
</style>
</head>
<body>

<h1>Nginx Reverse Proxy</h1>

<ul>
  <li><b>Environment:</b> ${environment}</li>
  <li><b>Instance:</b> $INSTANCE_ID</li>
  <li><b>Private IP:</b> $LOCAL_IPV4</li>
  <li><b>Public IP:</b> $PUBLIC_IPV4</li>
</ul>

<h2>Servicios</h2>
HTML

for SVC in $SERVICES; do
  NAME=$(echo "$SVC" | cut -d: -f1)
  PORT=$(echo "$SVC" | cut -d: -f2)
  TITLE=$(echo "$NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')

  if [ "${environment}" = "production" ]; then
    HOST="$NAME.${domain_name}"
  else
    HOST="$NAME-development.${domain_name}"
  fi

cat >> /usr/share/nginx/html/index.html <<HTML
<div class="card">
  <h3>$TITLE</h3>
  <div class="code">https://$HOST</div>
  <a href="https://$HOST" target="_blank">Abrir</a>
</div>
HTML
done

cat >> /usr/share/nginx/html/index.html <<HTML
</body>
</html>
HTML

############################################
# SSL CERTIFICATES
############################################
mkdir -p /etc/ssl/private /etc/ssl/certs

# Generate self-signed certificate (more reliable for automated deployments)
echo "Generating self-signed certificate for ${domain_name}"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/C=CL/ST=RM/L=Santiago/O=Development/OU=IT/CN=${domain_name}"

# Generate DH parameters (smaller size for faster deployment)
openssl dhparam -out /etc/ssl/certs/dhparam.pem 1024

echo "SSL certificates generated successfully"

############################################
# NGINX CONFIG - UNIFIED CONFIGURATION
############################################
cat > /etc/nginx/conf.d/default.conf <<NGX
resolver ${resolver} valid=10s ipv6=off;

map \$http_host \$service_name {
    default "";
    ~^(?<svc>[^.-]+)(-development)?\.${domain_name} \$svc;
}

# HTTP Configuration - Let's Encrypt challenge and dashboard
server {
    listen 80;
    server_name ${domain_name};
    root /usr/share/nginx/html;
    index index.html;
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        try_files \$uri \$uri/ =404;
    }
    
    # Dashboard for root domain
    location / {
        try_files \$uri \$uri/ =404;
    }
}

# HTTP Configuration - Subdomains
server {
    listen 80;
    server_name ~^(.+)\.${domain_name}$;

    location / {
        proxy_pass http://\$service_name.${namespace};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    error_page 502 503 504 /50x.html;
}

# HTTPS Configuration - Dashboard
server {
    listen 443 ssl http2;
    server_name ${domain_name};
    
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}

# HTTPS Configuration - Subdomains
server {
    listen 443 ssl http2;
    server_name ~^(.+)\.${domain_name}$;
    
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    location / {
        proxy_pass http://\$service_name.${namespace};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Proto https;
    }
    
    error_page 502 503 504 /50x.html;
}

# HTTP to HTTPS Redirect for root domain (if needed later)
# server {
#     listen 80;
#     server_name ${domain_name};
#     return 301 https://\$host\$request_uri;
# }

# HTTP to HTTPS Redirect for subdomains (if needed later)
# server {
#     listen 80;
#     server_name ~^(.+)\.${domain_name}$;
#     return 301 https://\$host\$request_uri;
# }
NGX

############################################
# ERROR PAGE
############################################
cat > /usr/share/nginx/html/50x.html <<EOF
<h1>Servicio no disponible</h1>
<p>Intenta nuevamente en unos segundos.</p>
EOF

############################################
# RELOAD
############################################
nginx -t
systemctl restart nginx

echo "======================================="
echo " NGINX ECS EDGE READY "
echo "======================================="
echo " Dashboard: http://$PUBLIC_IPV4"
echo " HTTPS:     https://${domain_name}"
echo " Subdomains: https://*.${domain_name}"
echo " Env:       ${environment}"
echo "======================================="
