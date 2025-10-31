output "nginx_public_ip" {
  description = "IP pública del servidor NGINX"
  value       = aws_eip.eip_nat.public_ip
}

output "nginx_instance_id" {
  description = "ID de la instancia NGINX"
  value       = aws_instance.nginx_proxy.id
}

output "namespace_id" {
  description = "ID del namespace de Service Discovery"
  value       = module.services_discovery.namespace_id
}

output "service_discovery_service_names" {
  description = "Nombres de los servicios registrados en Service Discovery"
  value       = module.services_discovery.service_names
}

output "service_discovery_service_ids" {
  description = "IDs de los servicios registrados en Service Discovery"
  value       = module.services_discovery.service_ids
}

output "service_discovery_service_arns" {
  description = "ARNs of the service discovery services"
  value       = module.services_discovery.service_arns
}


output "service_urls" {
  description = "URLs de acceso a los servicios via NGINX"
  value = {
    angular   = "http://${aws_eip.eip_nat.public_ip}/angular"
    react     = "http://${aws_eip.eip_nat.public_ip}/react"
    wordpress = "http://${aws_eip.eip_nat.public_ip}/blog"
  }
}

output "ssh_connection" {
  description = "Comando para conectarse via SSH"
  value       = "ssh -i '${aws_key_pair.key_pair.key_name}.pem' ec2-user@${aws_eip.eip_nat.public_dns}"
}
