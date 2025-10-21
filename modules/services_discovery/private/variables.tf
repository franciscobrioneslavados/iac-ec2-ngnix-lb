variable "services" {
  description = "Mapa de servicios para service discovery"
  type = map(object({
    name                           = string
    dns_type                       = string
    ttl                            = number
    routing_policy                 = string
    health_check_failure_threshold = number
  }))
  default = {}
}

variable "namespace_name" {
  description = "Cloud Map namespace ID"
  type        = string
  default     = "internal.ecs"
}

variable "vpc_id" {
  description = "VPC ID where the service discovery will be created"
  type        = string
}

variable "global_tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
