variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where resources will be deployed"
}

variable "CIDR_block" {
  description = "CIDR block for the VPC"
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for resource deployment"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for resource deployment"
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

variable "managed_by" {
  description = "value for the ManagedBy tag"
  type        = string
  default     = "Terraform"
}

variable "owner_name" {
  description = "value for the Owner tag"
  type        = string
}

variable "nginx_instance_type" {
  description = "Tipo de instancia para NGINX"
  type        = string
  default     = "t2.micro"
}

variable "nat_gateway_sg_id" {
  description = "ID of the NAT gateway security group"
}

variable "ssh_allowed_cidr" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
}

variable "domain_name" {
  description = "Domain name for the reverse proxy"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  type = string
}

variable "services" {
  description = "Servicios expuestos por el edge proxy"
  type        = map(string)
  default = {
    default = "80"
  }
}
