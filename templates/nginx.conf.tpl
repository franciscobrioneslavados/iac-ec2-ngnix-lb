user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    # Configuraciones básicas
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'upstream: $upstream_addr response_time: $upstream_response_time';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 1000;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Resolver DNS de VPC - CRÍTICO para Service Discovery
    resolver 169.254.169.253 valid=10s;
    resolver_timeout 5s;

    # Upstreams para balanceo de carga
    upstream angular_servers {
        least_conn;  # Balanceo por menor conexión
        server angular.${namespace_name}:80 max_fails=3 fail_timeout=30s;
        # Se agregarán más servidores automáticamente via Service Discovery
    }

    upstream react_servers {
        least_conn;
        server react.${namespace_name}:80 max_fails=3 fail_timeout=30s;
    }

    upstream wordpress_servers {
        ip_hash;  # Session persistence para WordPress
        server wordpress.${namespace_name}:80 max_fails=3 fail_timeout=30s;
    }

    upstream nestjs_servers {
        least_conn;
        server nestjs.${namespace_name}:3000 max_fails=3 fail_timeout=30s;
    }

    upstream python_servers {
        least_conn;
        server python.${namespace_name}:5000 max_fails=3 fail_timeout=30s;
    }

    # Configuración de rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=frontend:10m rate=100r/s;

    # Servidor principal
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        # Health check del load balancer
        location /lb-health {
            access_log off;
            add_header Content-Type text/plain;
            return 200 "LOAD_BALANCER_HEALTHY\n";
        }

        # Dashboard de servicios
        location = / {
            add_header Content-Type text/html;
            return 200 '<!DOCTYPE html>
<html>
<head>
    <title>🚀 NGINX Load Balancer</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; margin: -30px -30px 30px -30px; border-radius: 10px 10px 0 0; }
        .service { background: #f8f9fa; margin: 15px 0; padding: 20px; border-radius: 8px; border-left: 4px solid #007cba; }
        .service h3 { margin: 0 0 10px 0; color: #2c3e50; }
        .badge { background: #28a745; color: white; padding: 3px 8px; border-radius: 12px; font-size: 12px; }
        .url { font-family: monospace; background: #e9ecef; padding: 5px 10px; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 NGINX Load Balancer</h1>
            <p>Balanceador de Carga para ECS - Service Discovery</p>
        </div>
        
        <div class="service">
            <h3>🅰️ Angular Frontend <span class="badge">Load Balanced</span></h3>
            <p><strong>URL:</strong> <span class="url">/angular/</span></p>
            <p><strong>Strategy:</strong> Least Connections</p>
        </div>
        
        <div class="service">
            <h3>⚛️ React Frontend <span class="badge">Load Balanced</span></h3>
            <p><strong>URL:</strong> <span class="url">/react/</span></p>
            <p><strong>Strategy:</strong> Least Connections</p>
        </div>
        
        <div class="service">
            <h3>📝 WordPress <span class="badge">Session Persistent</span></h3>
            <p><strong>URL:</strong> <span class="url">/blog/</span></p>
            <p><strong>Strategy:</strong> IP Hash (Sticky Sessions)</p>
        </div>
        
        <div class="service">
            <h3>🔷 NestJS API <span class="badge">Load Balanced</span></h3>
            <p><strong>URL:</strong> <span class="url">/api/</span></p>
            <p><strong>Strategy:</strong> Least Connections + Rate Limiting</p>
        </div>
        
        <div class="service">
            <h3>🐍 Python API <span class="badge">Load Balanced</span></h3>
            <p><strong>URL:</strong> <span class="url">/python-api/</span></p>
            <p><strong>Strategy:</strong> Least Connections</p>
        </div>
        
        <div style="margin-top: 30px; padding: 15px; background: #e7f3ff; border-radius: 8px;">
            <p><strong>🔍 Namespace:</strong> ${namespace_name}</p>
            <p><strong>📊 Load Balancer Health:</strong> <a href="/lb-health">/lb-health</a></p>
            <p><strong>📈 NGINX Status:</strong> <a href="/nginx-status">/nginx-status</a></p>
        </div>
    </div>
</body>
</html>';
        }

        # Angular App - Balanceo de carga
        location /angular/ {
            limit_req zone=frontend burst=20 nodelay;
            
            proxy_pass http://angular_servers/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            
            # Configuración de balanceo
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
            proxy_connect_timeout 5s;
            proxy_read_timeout 30s;
            proxy_send_timeout 30s;
            
            # Health check
            proxy_intercept_errors on;
            
            access_log /var/log/nginx/angular.access.log main;
        }

        # React App - Balanceo de carga
        location /react/ {
            limit_req zone=frontend burst=20 nodelay;
            
            proxy_pass http://react_servers/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
            proxy_connect_timeout 5s;
            proxy_read_timeout 30s;
            
            access_log /var/log/nginx/react.access.log main;
        }

        # WordPress - Session persistence
        location /blog/ {
            proxy_pass http://wordpress_servers/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            
            # Session persistence para WordPress
            proxy_cookie_path / /;
            
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
            proxy_connect_timeout 5s;
            proxy_read_timeout 30s;
            
            access_log /var/log/nginx/wordpress.access.log main;
        }

        # NestJS API - Balanceo + Rate limiting
        location /api/ {
            limit_req zone=api burst=10 nodelay;
            
            proxy_pass http://nestjs_servers/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Configuración para APIs
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
            proxy_connect_timeout 3s;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;
            
            # CORS para APIs
            add_header Access-Control-Allow-Origin "*" always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Authorization, Content-Type, X-Requested-With" always;
            
            if ($request_method = OPTIONS) {
                return 204;
            }
            
            access_log /var/log/nginx/api.access.log main;
        }

        # Python Flask API - Balanceo
        location /python-api/ {
            limit_req zone=api burst=10 nodelay;
            
            proxy_pass http://python_servers/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
            proxy_connect_timeout 3s;
            proxy_read_timeout 10s;
            
            # CORS
            add_header Access-Control-Allow-Origin "*" always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Authorization, Content-Type, X-Requested-With" always;
            
            if ($request_method = OPTIONS) {
                return 204;
            }
            
            access_log /var/log/nginx/python-api.access.log main;
        }

        # Métricas NGINX para monitoreo
        location /nginx-status {
            stub_status on;
            access_log off;
            allow 10.0.0.0/8;  # Solo VPC interna
            deny all;
        }

        # Health check detallado
        location /health {
            access_log off;
            add_header Content-Type application/json;
            return 200 '{"status":"healthy","load_balancer":"nginx","timestamp":"$time_iso8601"}';
        }
    }

    # Configuración de compresión
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
}