variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto para tagging"
  type        = string
  default     = "nginx-reverse-proxy"
}

variable "environment" {
  description = "aws environment"
  type        = string
  default     = "development"
}

variable "namespace_name" {
  description = "Nombre del namespace para Service Discovery"
  type        = string
  default     = "internal.ecs"
}

variable "managed_by" {
  description = "value for the ManagedBy tag"
  type        = string
  default     = "Terraform"
}

variable "owner_name" {
  description = "value for the Owner tag"
  type        = string
  default     = "Francisco Briones"
}

variable "nginx_instance_type" {
  description = "Tipo de instancia para NGINX"
  type        = string
  default     = "t3.micro"
}

variable "ssh_allowed_cidr" {
  default = ["201.223.100.240/32"]
}

variable "ssh_public_key_path" {
  description = "Ruta a la clave pública SSH"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}