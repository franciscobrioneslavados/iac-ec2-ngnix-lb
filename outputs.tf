output "nginx_public_ip" {
  description = "IP pública del servidor NGINX"
  value       = aws_eip.eip_nat.public_ip
}

output "nginx_instance_id" {
  description = "ID de la instancia NGINX"
  value       = aws_instance.nginx_proxy.id
}

output "ssh_connection" {
  description = "Comando para conectarse via SSH"
  value       = "ssh -i '${aws_key_pair.key_pair.key_name}.pem' ubuntu@${aws_eip.eip_nat.public_dns}"
}

output "nginx_security_group_id" {
  description = "ID del Security Group de NGINX"
  value       = aws_security_group.nginx.id
}
