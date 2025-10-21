#!/bin/bash
# scripts/setup-nginx.sh
# Instalación optimizada para NGINX Load Balancer

set -e

# Variables
NAMESPACE=${1:-"internal.ecs"}

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "🚀 Iniciando instalación de NGINX Load Balancer"

# Actualizar sistema
log "📦 Actualizando sistema..."
yum update -y

# Instalar NGINX
log "🔧 Instalando NGINX..."
amazon-linux-extras enable nginx1
yum clean metadata
yum install -y nginx

# Instalar herramientas de monitoreo
log "📊 Instalando herramientas de monitoreo..."
yum install -y bind-utils jq htop sysstat

# Configurar NGINX como load balancer
log "⚙️ Configurando NGINX como load balancer..."

# Backup configuración original
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

# Generar configuración desde template
if [[ -f "/tmp/nginx.conf.tpl" ]]; then
    sed "s|\\\${namespace_name}|$NAMESPACE|g" /tmp/nginx.conf.tpl > /etc/nginx/nginx.conf
else
    log "⚠️ Template no encontrado, usando configuración por defecto"
fi

# Crear directorios para logs
mkdir -p /var/log/nginx/services

# Configurar logrotate para load balancer
cat > /etc/logrotate.d/nginx << EOF
/var/log/nginx/*.log /var/log/nginx/services/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 nginx nginx
    postrotate
        /bin/kill -USR1 \$(cat /var/run/nginx.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
EOF

# Scripts de monitoreo para load balancer
mkdir -p /opt/nginx/scripts

# Health check avanzado para balanceo
cat > /opt/nginx/scripts/lb-health-check.sh << 'EOF'
#!/bin/bash
# Health Check avanzado para Load Balancer

echo "🔍 Load Balancer Health Check - $(date)"
echo "=========================================="

# Verificar estado NGINX
if systemctl is-active --quiet nginx; then
    echo "✅ NGINX Service: ACTIVE"
else
    echo "❌ NGINX Service: INACTIVE"
    exit 1
fi

# Verificar configuración
if nginx -t > /dev/null 2>&1; then
    echo "✅ NGINX Configuration: VALID"
else
    echo "❌ NGINX Configuration: INVALID"
    nginx -t
    exit 1
fi

# Verificar servicios upstream
SERVICES=("angular" "react" "wordpress" "nestjs" "python")
ALL_HEALTHY=true

for service in "${SERVICES[@]}"; do
    if nslookup "$service.$NAMESPACE" > /dev/null 2>&1; then
        echo "✅ $service.$NAMESPACE: DNS RESOLVES"
    else
        echo "⚠️ $service.$NAMESPACE: DNS FAILED"
        ALL_HEALTHY=false
    fi
done

# Test de conectividad del load balancer
if curl -s http://localhost/lb-health > /dev/null; then
    echo "✅ Load Balancer Health Endpoint: RESPONDING"
else
    echo "❌ Load Balancer Health Endpoint: FAILED"
    ALL_HEALTHY=false
fi

# Métricas NGINX
if curl -s http://localhost/nginx-status > /dev/null 2>&1; then
    echo "✅ NGINX Status Endpoint: ACCESSIBLE"
else
    echo "⚠️ NGINX Status Endpoint: RESTRICTED (VPC only)"
fi

echo "=========================================="
if $ALL_HEALTHY; then
    echo "🎉 LOAD BALANCER STATUS: HEALTHY"
    exit 0
else
    echo "💥 LOAD BALANCER STATUS: DEGRADED"
    exit 1
fi
EOF

# Script para métricas de balanceo
cat > /opt/nginx/scripts/lb-metrics.sh << 'EOF'
#!/bin/bash
# Métricas del Load Balancer

echo "📊 NGINX Load Balancer Metrics"
echo "==============================="

# Obtener estadísticas NGINX
echo "Active Connections:"
curl -s http://localhost/nginx-status 2>/dev/null | head -3 || echo "Metrics endpoint not accessible"

echo ""
echo "Connection Statistics:"
netstat -an | grep :80 | wc -l | xargs echo "HTTP Connections:"

echo ""
echo "Load Balancer Upstreams:"
echo "Angular: $(dig +short angular.$NAMESPACE | wc -l) instances"
echo "React: $(dig +short react.$NAMESPACE | wc -l) instances" 
echo "WordPress: $(dig +short wordpress.$NAMESPACE | wc -l) instances"
echo "NestJS: $(dig +short nestjs.$NAMESPACE | wc -l) instances"
echo "Python: $(dig +short python.$NAMESPACE | wc -l) instances"
EOF

chmod +x /opt/nginx/scripts/*.sh

# Optimizar sistema para load balancer
log "🎯 Optimizando sistema para load balancer..."

# Aumentar límites de archivos
echo "nginx soft nofile 65536" >> /etc/security/limits.conf
echo "nginx hard nofile 65536" >> /etc/security/limits.conf

# Configurar sysctl para alto rendimiento
cat >> /etc/sysctl.conf << EOF
# Optimizaciones para NGINX Load Balancer
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
EOF

sysctl -p

# Iniciar servicios
log "🚀 Iniciando NGINX Load Balancer..."
systemctl enable nginx
systemctl start nginx

# Verificar inicio
if systemctl is-active --quiet nginx; then
    log "✅ NGINX Load Balancer iniciado correctamente"
else
    log "❌ Error al iniciar NGINX"
    journalctl -u nginx --no-pager -l
    exit 1
fi

# Test de configuración
if nginx -t; then
    log "✅ Configuración de load balancer válida"
else
    log "❌ Error en configuración"
    exit 1
fi

# Configurar cron para monitoreo
cat > /etc/cron.hourly/nginx-lb-health << EOF
#!/bin/bash
/opt/nginx/scripts/lb-health-check.sh > /var/log/nginx-lb-health.log 2>&1
EOF
chmod +x /etc/cron.hourly/nginx-lb-health

# Información final
log "🎉 NGINX Load Balancer instalado exitosamente!"
echo ""
echo "📊 INFORMACIÓN DEL LOAD BALANCER:"
echo "   Namespace: $NAMESPACE"
echo "   Health Check: http://localhost/lb-health"
echo "   NGINX Status: http://localhost/nginx-status (VPC only)"
echo "   Dashboard: http://localhost/"
echo ""
echo "🔧 HERRAMIENTAS:"
echo "   Health Check: /opt/nginx/scripts/lb-health-check.sh"
echo "   Metrics: /opt/nginx/scripts/lb-metrics.sh"
echo ""
echo "📈 ESTRATEGIAS DE BALANCEO:"
echo "   Angular/React: Least Connections"
echo "   WordPress: IP Hash (Session Persistence)"
echo "   APIs: Least Connections + Rate Limiting"

# Registrar instalación
echo "Load Balancer instalado: $(date)" > /var/log/nginx-lb-install.log