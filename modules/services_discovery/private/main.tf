# modules/service-discovery/main.tf
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = var.namespace_name
  description = "Private DNS namespace for ECS services"
  vpc         = var.vpc_id

  tags = merge(var.global_tags, {
    "SD Private DNS Name" = "${var.global_tags["ProjectName"]}-${var.global_tags["Environment"]}-sd-namespace"
  })
}

resource "aws_service_discovery_service" "this" {
  for_each = var.services

  name = each.value.name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      type = each.value.dns_type
      ttl  = each.value.ttl
    }

    routing_policy = each.value.routing_policy
  }

  health_check_custom_config {
    failure_threshold = each.value.health_check_failure_threshold
  }

  tags = merge(var.global_tags, {
    "SD Service" = each.value.name
  })
}
