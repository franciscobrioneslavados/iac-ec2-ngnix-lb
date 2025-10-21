#!/bin/bash
# User Data final para NGINX Load Balancer

# Variables
NAMESPACE="${namespace_name}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> /var/log/nginx-setup.log
}

log "🚀 Iniciando NGINX Load Balancer desde AMI optimizada"

# Instalar NGINX (por si la AMI no lo tiene)
if ! which nginx > /dev/null 2>&1; then
    log "📦 Instalando NGINX..."
    yum update -y
    amazon-linux-extras enable nginx1
    yum clean metadata
    yum install -y nginx
fi

# Crear configuración del load balancer
log "⚙️ Configurando Load Balancer..."
cat > /etc/nginx/conf.d/load-balancer.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Health checks
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    location /lb-health {
        access_log off;
        return 200 "LOAD_BALANCER_HEALTHY\n";
        add_header Content-Type text/plain;
    }
    
    # Dashboard principal con UTF-8
    location / {
        add_header Content-Type "text/html; charset=utf-8";
        return 200 '<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🚀 NGINX Load Balancer</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; color: #333; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 0; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow: hidden; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }
        .status { background: #d4edda; padding: 20px; margin: 20px; border-radius: 8px; border-left: 4px solid #28a745; }
        .services { padding: 20px; }
        .service-list { background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 15px 0; }
        ul { line-height: 1.6; }
        a { color: #007bff; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 NGINX Load Balancer</h1>
            <p>Balanceador de Carga - Listo para ECS</p>
        </div>
        
        <div class="status">
            <h3>✅ NGINX Configurado Correctamente</h3>
            <p>El load balancer está funcionando. Los servicios ECS se conectarán automáticamente via Service Discovery.</p>
        </div>
        
        <div class="services">
            <h3>📊 Endpoints Disponibles:</h3>
            <div class="service-list">
                <ul>
                    <li><a href="/health">/health</a> - Estado del load balancer</li>
                    <li><a href="/lb-health">/lb-health</a> - Estado específico del balanceador</li>
                </ul>
            </div>
            
            <h3>🔧 Servicios (disponibles cuando ECS esté desplegado):</h3>
            <div class="service-list">
                <ul>
                    <li><strong>/angular/</strong> - Angular Frontend</li>
                    <li><strong>/react/</strong> - React Frontend</li>
                    <li><strong>/blog/</strong> - WordPress</li>
                    <li><strong>/api/</strong> - NestJS API</li>
                    <li><strong>/python-api/</strong> - Python Flask API</li>
                </ul>
            </div>
            
            <div style="margin-top: 20px; padding: 15px; background: #fff3cd; border-radius: 5px; border-left: 4px solid #ffc107;">
                <p><strong>⚠️ Nota:</strong> Los servicios mostrarán error 502 hasta que los contenedores ECS estén desplegados.</p>
            </div>
        </div>
    </div>
</body>
</html>';
    }
    
    # Placeholder para servicios futuros
    location /angular/ {
        return 502 "Service Angular not deployed yet\n";
        add_header Content-Type text/plain;
    }
    
    location /react/ {
        return 502 "Service React not deployed yet\n";
        add_header Content-Type text/plain;
    }
    
    location /blog/ {
        return 502 "Service WordPress not deployed yet\n";
        add_header Content-Type text/plain;
    }
    
    location /api/ {
        return 502 "Service NestJS API not deployed yet\n";
        add_header Content-Type text/plain;
    }
    
    location /python-api/ {
        return 502 "Service Python API not deployed yet\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Agregar resolver DNS al nginx.conf principal
if ! grep -q "resolver 169.254.169.253" /etc/nginx/nginx.conf; then
    sed -i '/http {/a\    resolver 169.254.169.253 valid=10s;' /etc/nginx/nginx.conf
fi

# Iniciar o reiniciar NGINX
log "🔧 Iniciando servicios..."
if systemctl is-active nginx; then
    systemctl reload nginx
    log "✅ NGINX recargado"
else
    systemctl enable nginx
    systemctl start nginx
    log "✅ NGINX iniciado"
fi

# Health check final
sleep 3
if curl -s http://localhost/health > /dev/null; then
    log "🎉 Load Balancer HEALTHY"
else
    log "⚠️ Load Balancer health check failed"
    exit 1
fi

log "✅ NGINX Load Balancer deployment completado"
echo "Deployment finalizado: $(date)" > /var/log/nginx-deployment-complete.log