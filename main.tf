locals {
  global_tags = {
    "Environment" = var.environment
    "ManagedBy"   = var.managed_by
    "OwnerName"   = var.owner_name
    "ProjectName" = var.project_name
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "services_discovery" {
  source = "./modules/services_discovery/private"

  vpc_id         = "vpc-031fe67ff94c9e969"
  namespace_name = "internal.ecs"
  services = {
    # Backend APIs (privados)
    nestjs-api = {
      name                           = "nestjs"
      dns_type                       = "A"
      ttl                            = 60
      routing_policy                 = "MULTIVALUE"
      health_check_failure_threshold = 2
    },

    python-api = {
      name                           = "python"
      dns_type                       = "A"
      ttl                            = 60
      routing_policy                 = "MULTIVALUE"
      health_check_failure_threshold = 2
    },

    postgresql = {
      name                           = "postgresql"
      dns_type                       = "SRV" # Para servicios con puerto específico
      ttl                            = 300
      routing_policy                 = "MULTIVALUE"
      health_check_failure_threshold = 3
    },

    # Frontends (accesibles via ALB, pero discovery interno)
    wordpress = {
      name                           = "wordpress"
      dns_type                       = "A"
      ttl                            = 60
      routing_policy                 = "MULTIVALUE"
      health_check_failure_threshold = 2
    },

    angular-frontend = {
      name                           = "angular"
      dns_type                       = "A"
      ttl                            = 60
      routing_policy                 = "MULTIVALUE"
      health_check_failure_threshold = 2
    },

    react-frontend = {
      name                           = "react"
      dns_type                       = "A"
      ttl                            = 60
      routing_policy                 = "MULTIVALUE"
      health_check_failure_threshold = 2
    }
  }
  global_tags = local.global_tags
}

# Security Group para NGINX
resource "aws_security_group" "nginx" {
  name        = "${var.project_name}-nginx-sg"
  description = "Security group for NGINX reverse proxy"
  vpc_id      = "vpc-031fe67ff94c9e969"

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS (opcional para futuro)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # SSH (restringido a tu IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr
    description = "SSH access"
  }

  # Egress - permitir todo el tráfico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-nginx-sg"
  }
}


# Key Pair para SSH (opcional)
# Generar clave SSH automáticamente
resource "tls_private_key" "nginx" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "nginx" {
  key_name   = "${var.environment}-${var.project_name}-key"
  public_key = tls_private_key.nginx.public_key_openssh

  tags = {
    Name = "${var.project_name}-keypair"
  }
}

# Guardar la clave privada localmente
resource "local_file" "private_key" {
  content         = tls_private_key.nginx.private_key_pem
  filename        = "${path.module}/${aws_key_pair.nginx.key_name}.pem"
  file_permission = "0600"
}


# EC2 Instance para NGINX
resource "aws_instance" "nginx_proxy" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.nginx_instance_type
  subnet_id     = "subnet-0362da2f59b930c81"

  vpc_security_group_ids = [aws_security_group.nginx.id]
  key_name               = aws_key_pair.nginx.key_name

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh.tpl", {
    namespace_name = var.namespace_name
  }))


  tags = merge(local.global_tags, {
    Name = "ec2-${var.environment}-${var.project_name}-instance"
  })

  depends_on = [aws_key_pair.nginx]

}

# Elastic IP para instancia NGINX
resource "aws_eip" "nginx" {
  instance = aws_instance.nginx_proxy.id
  domain   = "vpc"

  tags = {
    Name = "${var.environment}-${var.project_name}-nginx-eip"
  }
}

