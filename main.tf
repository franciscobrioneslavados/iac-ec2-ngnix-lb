locals {
  global_tags = {
    "Environment" = var.environment
    "ManagedBy"   = var.managed_by
    "OwnerName"   = var.owner_name
    "ProjectName" = var.project_name
  }
  services_json = jsonencode(var.services)
  #example {
  #  wordpress: "8080"
  #  n8n: "5678"
  #}
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# permitir calcular el DNS del VPC (AmazonProvidedDNS = base+2)
data "aws_vpc" "selected" {
  id = var.vpc_id
}
data "cloudflare_ip_ranges" "cf" {}

# Security Group para NGINX
resource "aws_security_group" "nginx" {
  name        = "${var.project_name}-nginx-sg"
  description = "Security group for NGINX reverse proxy"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = concat(data.cloudflare_ip_ranges.cf.ipv4_cidrs, ["0.0.0.0/0"])
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = concat(data.cloudflare_ip_ranges.cf.ipv4_cidrs, ["0.0.0.0/0"])
  }

  # SSH access desde tu IP (opcional para administración)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr # Cambia esto por tu IP específica
  }

  # ICMP (ping)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.ssh_allowed_cidr
  }



  # Egress - permitir todo el tráfico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.global_tags, {
    Name = "${var.environment}-${var.project_name}-sg"
  })
}

# Generar clave SSH automáticamente
resource "tls_private_key" "nginx" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = "${var.environment}-${var.project_name}-key"
  public_key = tls_private_key.nginx.public_key_openssh

  tags = merge(local.global_tags, {
    Name = "${var.environment}-${var.project_name}-keypair"
  })
}

# Guardar la clave privada localmente
resource "local_file" "private_key" {
  content         = tls_private_key.nginx.private_key_pem
  filename        = "${path.module}/${aws_key_pair.key_pair.key_name}.pem"
  file_permission = "0400"
}

# EC2 Instance para NGINX
resource "aws_instance" "nginx_proxy" {
  ami           = data.aws_ami.ubuntu_22_04.id
  instance_type = var.nginx_instance_type
  subnet_id     = var.public_subnet_ids[0]

  vpc_security_group_ids      = [aws_security_group.nginx.id]
  key_name                    = aws_key_pair.key_pair.key_name
  iam_instance_profile        = aws_iam_instance_profile.nginx_lb_profile.name
  user_data_replace_on_change = true


  user_data = templatefile("${path.module}/templates/user-data-ubuntu_v2.sh", {
    environment          = var.environment
    domain_name          = var.domain_name
    namespace            = "container-edge-${var.environment}.local"
    resolver             = cidrhost(data.aws_vpc.selected.cidr_block, 2)
    cloudflare_api_token = var.cloudflare_api_token
    services_json        = local.services_json
  })


  root_block_device {
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(local.global_tags, {
    Name = "ec2-${var.environment}-${var.project_name}-instance"
  })

  depends_on = [
    aws_key_pair.key_pair,
    aws_iam_instance_profile.nginx_lb_profile
  ]

}

resource "aws_eip" "eip_nat" {
  domain = "vpc"

  tags = merge(local.global_tags, {
    Name = "${var.environment}-${var.project_name}-eip"
  })
}

resource "aws_eip_association" "nat_eip_assoc" {
  instance_id   = aws_instance.nginx_proxy.id
  allocation_id = aws_eip.eip_nat.id
  # allocation_id        = aws_eip.eip_nat.id
  # network_interface_id = aws_instance.nginx_proxy.primary_network_interface_id
}

resource "aws_iam_role" "nginx_lb_role" {
  name        = "nginx-lb-role"
  description = "Rol IAM para la instancia NGINX Load Balancer con permisos para AWS Cloud Map"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.global_tags, {
    Name = "iam-${var.environment}-${var.project_name}-nginx-lb-role"
  })
}

# Permisos mínimos para descubrir servicios en Cloud Map
data "aws_iam_policy_document" "nginx_lb_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "servicediscovery:ListServices",
      "servicediscovery:DiscoverInstances",
      "servicediscovery:GetService",
      "servicediscovery:ListInstances",
      "ec2:DescribeInstances", # opcional, para futuras extensiones
      "ec2:CreateTags",        # para etiquetado automático
      "ec2:DescribeTags",      # para ver etiquetas
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "nginx_lb_policy" {
  name        = "nginx-lb-cloudmap-policy"
  description = "Permite a la instancia NGINX consultar AWS Cloud Map"
  policy      = data.aws_iam_policy_document.nginx_lb_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "nginx_lb_policy_attach" {
  role       = aws_iam_role.nginx_lb_role.name
  policy_arn = aws_iam_policy.nginx_lb_policy.arn
}

resource "aws_iam_instance_profile" "nginx_lb_profile" {
  name = "iam-${var.environment}-${var.project_name}-nginx-lb-instance-profile"
  role = aws_iam_role.nginx_lb_role.name

  depends_on = [aws_iam_role_policy_attachment.nginx_lb_policy_attach]

  tags = merge(local.global_tags, {
    Name = "iam-${var.environment}-${var.project_name}-nginx-lb-instance-profile"
  })
}
