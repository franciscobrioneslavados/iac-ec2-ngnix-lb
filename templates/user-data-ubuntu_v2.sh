#!/bin/bash
set -euo pipefail

LOG="/var/log/cloud-init-output.log"
exec > >(tee -a "$LOG") 2>&1

echo "===== Cloud-init start $(date) ====="

#############################
# VARIABLES DESDE TERRAFORM #
#############################
ENVIRONMENT="${environment}"
DOMAIN_NAME="${domain_name}"
NAMESPACE="${namespace}"
SERVICES_JSON='${services_json}'
RESOLVER="${resolver}"
CLOUDFLARE_API_TOKEN="${cloudflare_api_token}"

################
# METADATA EC2 #
################
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
HOSTNAME=$(hostname)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=$(echo "$AZ" | sed 's/.$//')
CPU=$(nproc)
MEMORY=$(free -m | awk '/Mem:/ {print $2}')

############
# SISTEMA #
############
apt-get update -y
apt-get install -y nginx curl jq openssl certbot python3-certbot-dns-cloudflare

systemctl enable nginx

#################
# CERT SELF-SIGNED (BOOTSTRAP)
#################
mkdir -p /etc/ssl/private /etc/ssl/certs

if [ ! -f /etc/ssl/private/nginx-selfsigned.key ]; then
  echo "Generating self-signed certificate..."
  openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/C=CL/ST=RM/L=Santiago/O=Edge/CN=$DOMAIN_NAME"

  openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
fi

#########################
# HTML DINÁMICO (EDGE) #
#########################
cat > /var/www/html/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Edge Proxy Dashboard</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { 
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
  padding: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.container {
  background: rgba(255, 255, 255, 0.95);
  border-radius: 20px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3);
  max-width: 900px;
  width: 100%;
  overflow: hidden;
}
.header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 40px;
  text-align: center;
}
.header h1 {
  font-size: 2.5em;
  margin-bottom: 10px;
}
.header p {
  opacity: 0.9;
  font-size: 1.1em;
}
.content {
  padding: 40px;
}
.section {
  margin-bottom: 30px;
}
.section h2 {
  color: #667eea;
  margin-bottom: 15px;
  font-size: 1.5em;
  border-bottom: 2px solid #667eea;
  padding-bottom: 10px;
}
.info-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 15px;
  margin-bottom: 20px;
}
.info-item {
  background: #f8f9fa;
  padding: 15px;
  border-radius: 10px;
  border-left: 4px solid #667eea;
}
.info-item strong {
  color: #333;
  display: block;
  margin-bottom: 5px;
}
.info-item span {
  color: #666;
  font-family: monospace;
}
.services-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 15px;
}
.service-card {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 20px;
  border-radius: 12px;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
  cursor: pointer;
}
.service-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 10px 25px rgba(102, 126, 234, 0.4);
}
.service-name {
  font-size: 1.3em;
  font-weight: bold;
  margin-bottom: 8px;
}
.service-url {
  font-size: 0.9em;
  opacity: 0.9;
  word-break: break-all;
}
.service-port {
  font-size: 0.85em;
  opacity: 0.7;
  margin-top: 5px;
}
.status-badge {
  display: inline-block;
  background: #10b981;
  color: white;
  padding: 5px 15px;
  border-radius: 20px;
  font-size: 0.9em;
  margin-top: 10px;
}
@media (max-width: 768px) {
  .header h1 { font-size: 1.8em; }
  .content { padding: 20px; }
  .info-grid { grid-template-columns: 1fr; }
}
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>🚀 Edge Proxy Dashboard</h1>
    <p>Reverse Proxy & Service Discovery</p>
  </div>
  
  <div class="content">
    <div class="section">
      <h2>📊 System Information</h2>
      <div class="info-grid">
        <div class="info-item">
          <strong>Environment</strong>
          <span>ENVIRONMENT_PLACEHOLDER</span>
        </div>
        <div class="info-item">
          <strong>Domain</strong>
          <span>DOMAIN_PLACEHOLDER</span>
        </div>
        <div class="info-item">
          <strong>Instance ID</strong>
          <span>INSTANCE_ID_PLACEHOLDER</span>
        </div>
        <div class="info-item">
          <strong>Instance Type</strong>
          <span>INSTANCE_TYPE_PLACEHOLDER</span>
        </div>
        <div class="info-item">
          <strong>Region</strong>
          <span>REGION_PLACEHOLDER</span>
        </div>
        <div class="info-item">
          <strong>Public IP</strong>
          <span>PUBLIC_IP_PLACEHOLDER</span>
        </div>
        <div class="info-item">
          <strong>CPU Cores</strong>
          <span>CPU_PLACEHOLDER</span>
        </div>
        <div class="info-item">
          <strong>Memory</strong>
          <span>MEMORY_PLACEHOLDER MB</span>
        </div>
      </div>
    </div>

    <div class="section">
      <h2>🔗 Available Services</h2>
      <div class="services-grid">
        SERVICES_PLACEHOLDER
      </div>
    </div>
  </div>
</div>
</body>
</html>
HTMLEOF

# Reemplazar placeholders
sed -i "s|ENVIRONMENT_PLACEHOLDER|$ENVIRONMENT|g" /var/www/html/index.html
sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN_NAME|g" /var/www/html/index.html
sed -i "s|INSTANCE_ID_PLACEHOLDER|$INSTANCE_ID|g" /var/www/html/index.html
sed -i "s|INSTANCE_TYPE_PLACEHOLDER|$INSTANCE_TYPE|g" /var/www/html/index.html
sed -i "s|REGION_PLACEHOLDER|$REGION|g" /var/www/html/index.html
sed -i "s|PUBLIC_IP_PLACEHOLDER|$PUBLIC_IP|g" /var/www/html/index.html
sed -i "s|CPU_PLACEHOLDER|$CPU|g" /var/www/html/index.html
sed -i "s|MEMORY_PLACEHOLDER|$MEMORY|g" /var/www/html/index.html

# Generar cards de servicios
SERVICES_HTML=""
echo "$SERVICES_JSON" | jq -r 'to_entries[] | @base64' | while read -r row; do
  SERVICE_NAME=$(echo "$row" | base64 -d | jq -r '.key')
  SERVICE_PORT=$(echo "$row" | base64 -d | jq -r '.value')
  SERVICE_URL="https://$SERVICE_NAME.$DOMAIN_NAME"
  
  SERVICES_HTML+="<div class=\"service-card\" onclick=\"window.location.href='$SERVICE_URL'\">
  <div class=\"service-name\">$SERVICE_NAME</div>
  <div class=\"service-url\">$SERVICE_URL</div>z
  <div class=\"service-port\">Backend Port: $SERVICE_PORT</div>
  <div class=\"status-badge\">Active</div>
</div>
"
done

# Insertar servicios en HTML
sed -i "s|SERVICES_PLACEHOLDER|$SERVICES_HTML|g" /var/www/html/index.html

chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www

################
# NGINX HTTP → HTTPS REDIRECT
################
cat > /etc/nginx/sites-available/default <<'NGINXEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Redirect all HTTP to HTTPS
    return 301 https://$host$request_uri;
}
NGINXEOF

########################
# NGINX: SERVICES MAP (puerto por servicio)
########################
cat > /etc/nginx/conf.d/01-services-map.conf <<'MAPEOF'
# Mapeo de servicio → puerto backend
map $service_name $backend_port {
    default 80;
MAPEOF

echo "$SERVICES_JSON" | jq -r 'to_entries[] | "    \(.key) \(.value);"' >> /etc/nginx/conf.d/01-services-map.conf

cat >> /etc/nginx/conf.d/01-services-map.conf <<'MAPEOF'
}

# Extractor de subdomain desde Host header
map $http_host $service_name {
MAPEOF

echo "$SERVICES_JSON" | jq -r 'keys[] | "    ~^\(.)\\..+$  \(.);"' >> /etc/nginx/conf.d/01-services-map.conf

cat >> /etc/nginx/conf.d/01-services-map.conf <<'MAPEOF'
    default "";
}
MAPEOF

#################
# NGINX HTTPS: PROXY REVERSO
#################
cat > /etc/nginx/sites-available/default-ssl <<SSLEOF
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    
    server_name $DOMAIN_NAME *.$DOMAIN_NAME;

    # Upstream para resolver DNS dinámicamente
    resolver $RESOLVER valid=10s ipv6=off;

    # Certificados SSL (inicialmente self-signed)
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logs
    access_log /var/log/nginx/edge-access.log;
    error_log /var/log/nginx/edge-error.log;

    # Root y index para el dashboard (dominio principal)
    root /var/www/html;
    index index.html;

    # CASO 1: Dominio principal → Dashboard (sin subdomain)
    location / {
        # Si no hay servicio detectado, servir archivos estáticos
        try_files \$uri \$uri/ @proxy;
    }

    # CASO 2: Subdomain detectado → Proxy reverso
    location @proxy {
        # Solo hacer proxy si hay un servicio detectado
        if (\$service_name = "") {
            return 404;
        }

        set \$backend_url "http://\$service_name.$NAMESPACE:\$backend_port";
        
        proxy_pass \$backend_url;
        proxy_http_version 1.1;
        
        # Headers de proxy
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffering
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
SSLEOF

ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/default-ssl /etc/nginx/sites-enabled/default-ssl

########################
# CLOUDFLARE CREDENTIALS
########################
mkdir -p /etc/cloudflare
cat > /etc/cloudflare/token <<CFEOF
dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN
CFEOF
chmod 600 /etc/cloudflare/token

########################
# TEST & START NGINX
########################
nginx -t && systemctl restart nginx || {
  echo "ERROR: Nginx configuration failed!"
  exit 1
}

########################
# CERTBOT: LET'S ENCRYPT (DNS-01 Challenge)
########################
echo "Requesting Let's Encrypt wildcard certificate..."

certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/cloudflare/token \
  --dns-cloudflare-propagation-seconds 30 \
  -d "$DOMAIN_NAME" \
  -d "*.$DOMAIN_NAME" \
  --staging \
  --agree-tos \
  -m "admin@$DOMAIN_NAME" \
  --non-interactive || {
    echo "⚠️  Certbot failed, continuing with self-signed certificate"
  }

########################
# SWITCH TO LETSENCRYPT CERT
########################
if [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ]; then
  echo "✅ Switching to Let's Encrypt certificate"

  sed -i \
    -e "s|/etc/ssl/certs/nginx-selfsigned.crt|/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem|" \
    -e "s|/etc/ssl/private/nginx-selfsigned.key|/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem|" \
    /etc/nginx/sites-available/default-ssl

  nginx -t && systemctl reload nginx
fi

########################
# AUTO-RENEWAL HOOK
########################
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh <<'HOOKEOF'
#!/bin/bash
systemctl reload nginx
HOOKEOF

chmod +x /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh

# Agregar cron job para renovación automática (ejecuta 2 veces al día)
(crontab -l 2>/dev/null; echo "0 3,15 * * * certbot renew --quiet") | crontab -

echo "===== ✅ Cloud-init completed successfully $(date) ====="
