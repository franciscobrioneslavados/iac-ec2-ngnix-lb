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

variable "namespace_name" {
  description = "Nombre del namespace para Service Discovery"
  type        = string
  default     = "internal-ecs"
}

variable "services" {
  description = "Lista de servicios manejados por el Load Balancer"
  type        = list(string)
  default     = ["angular", "react", "api", "blog", "python-api"]
}

variable "nginx_instance_type" {
  description = "Tipo de instancia para NGINX"
  type        = string
  default     = "t2.micro"
}

variable "ssh_allowed_cidr" {

}
