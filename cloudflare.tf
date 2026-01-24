# DNS Records

# Record para el dominio wildcard
resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  ttl     = 1
  name    = "*"
  type    = "A"
  content = aws_eip.eip_nat.public_ip
  comment = "Record para el proxy"
  proxied = false
}

# Record para el dominio raíz
resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  ttl     = 1
  name    = "@"
  type    = "A"
  content = aws_eip.eip_nat.public_ip
  comment = "Record para el proxy"
  proxied = false
}

# Record for www 
resource "cloudflare_dns_record" "www" {
  zone_id = var.cloudflare_zone_id
  ttl     = 1
  name    = "www"
  type    = "A"
  content = aws_eip.eip_nat.public_ip
  comment = "Record para el proxy"
  proxied = false
}


# # Force HTTPS
# # permiso para redirigir HTTP a HTTPS 
# # permiso en cloudflare api token like: Zone: Zone Settings: Edit
# # Example: https://example.com
# resource "cloudflare_ruleset" "force_https" {
#   zone_id = var.cloudflare_zone_id
#   name    = "Force HTTPS"
#   kind    = "zone"
#   phase   = "http_request_redirect"
# 
#   rules = [
#     {
#       ref         = "redirect_to_https"
#       description = "Redirect HTTP to HTTPS"
#       expression  = "(http.request.scheme eq \"http\")"
#       action      = "redirect"
# 
#       action_parameters = {
#         from_value = {
#           status_code = 301
#           target_url = {
#             expression = "concat(\"https://\", http.request.host, http.request.uri.path)"
#           }
#         }
#       }
#     }
#   ]
# }
# 
# # Block direct IP access
# # Permiso en cloudflare api token like: Zone: Zone Settings: Edit
# # Example: 127.0.0.1
# resource "cloudflare_ruleset" "block_direct_ip" {
#   zone_id = var.cloudflare_zone_id
#   name    = "Block direct IP access"
#   kind    = "zone"
#   phase   = "http_request_firewall_custom"
# 
#   rules = [
#     {
#       ref         = "block_ip_access"
#       description = "Block requests without hostname"
#       expression  = "(http.host eq \"\") or (http.host matches \"^[0-9.]+$\")"
#       action      = "block"
#     }
#   ]
# }
# 
# # Rate limit global 
# # Permiso en cloudflare api token like: Zone: Zone Settings: Edit
# # Example: /_internal /health
# resource "cloudflare_ruleset" "rate_limit_global" {
#   zone_id = var.cloudflare_zone_id
#   name    = "Global rate limit"
#   kind    = "zone"
#   phase   = "http_ratelimit"
# 
#   rules = [
#     {
#       ref         = "limit_per_ip"
#       description = "Limit requests per IP"
#       expression  = "(http.request.uri.path ne \"\")"
#       action      = "block"
# 
#       ratelimit = {
#         characteristics     = ["ip.src"]
#         period              = 60
#         requests_per_period = 300
#         mitigation_timeout  = 600
#       }
#     }
#   ]
# }
# 
# # Block internal paths
# # Permiso en cloudflare api token like: Zone: Zone Settings: Edit
# # Example: /_internal /health
# resource "cloudflare_ruleset" "block_internal_paths" {
#   zone_id = var.cloudflare_zone_id
#   name    = "Block internal paths"
#   kind    = "zone"
#   phase   = "http_request_firewall_custom"
# 
#   rules = [
#     {
#       ref         = "block_internal"
#       description = "Block internal paths"
#       expression  = "(http.request.uri.path starts_with \"/_internal\") or (http.request.uri.path starts_with \"/health\")"
#       action      = "block"
#     }
#   ]
# }
# 
# # WAF Managed Rules
# # Permiso en cloudflare api token like: Zone: Zone Settings: Edit
# # Description:  
# resource "cloudflare_ruleset" "managed_waf" {
#   zone_id = var.cloudflare_zone_id
#   name    = "Managed WAF"
#   kind    = "zone"
#   phase   = "http_request_firewall_managed"
# 
#   rules = [
#     {
#       ref        = "cf_managed_waf"
#       action     = "execute"
#       expression = "(cf.threat_score gt 3)"
#       action_parameters = {
#         id = "efb7b8c949ac4650a09736fc376e9aee"
#       }
#     }
#   ]
# }
