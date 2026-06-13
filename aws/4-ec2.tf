# TLS Private Key
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# AWS Secrets Manager Secret for the private key
resource "aws_secretsmanager_secret" "application_key" {
  name = "${var.environment}-app-secretkey"

  tags = {
    Name = "${var.environment}-app-secretkey"
  }
}

# Store the private key in Secrets Manager
resource "aws_secretsmanager_secret_version" "application_key" {
  secret_id     = aws_secretsmanager_secret.application_key.id
  secret_string = tls_private_key.key.private_key_pem
}

# AWS Key Pair for EC2
resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.environment}-ec2-key"
  public_key = tls_private_key.key.public_key_openssh

  tags = {
    Name = "${var.environment}-ec2-key"
  }
}

# Security Group for EC2 (least privilege)
resource "aws_security_group" "ec2" {
  name        = "condensation-${var.environment}-ec2-sg"
  description = "Security group for EC2 instance - restricted to necessary ports only"
  vpc_id      = aws_vpc.condensation.id

  # SSH - allow from anywhere (can be restricted to specific IPs via SSH_ALLOWED_CIDR variable)
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # HTTP - allow from public internet
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS - allow from public internet
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Frontend application port
  ingress {
    description = "Frontend service"
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend service ports
  ingress {
    description = "Backend service"
    from_port   = 8080
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Auth service
  ingress {
    description = "Auth service"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Monitoring ports (INTERNAL ONLY - least privilege)
  ingress {
    description = "NodeExporter Metrics (internal only)"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Only from within VPC
  }

  ingress {
    description = "Prometheus Metrics (internal only)"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Only from within VPC
  }

  ingress {
    description = "Grafana (internal only)"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Only from within VPC
  }

  # Outbound - restricted to necessary destinations
  # Allow outbound HTTP/HTTPS for package management and external APIs
  egress {
    description = "Allow HTTPS (package downloads, external APIs)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTP (package downloads)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow DNS
  egress {
    description = "Allow DNS queries"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow DNS queries TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound to RDS in private subnet
  egress {
    description = "Allow to RDS databases"
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_1_cidr, var.private_subnet_2_cidr]
  }

  egress {
    description = "Allow to RDS game database"
    from_port   = var.db_game_port
    to_port     = var.db_game_port
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_1_cidr, var.private_subnet_2_cidr]
  }

  tags = {
    Name = "condensation-${var.environment}-ec2-sg"
  }
}

# EC2 Instance in public subnet for external access
resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.ec2_instance_type
  key_name                    = aws_key_pair.ec2_key.key_name
  iam_instance_profile        = "LabInstanceProfile"
  associate_public_ip_address = true

  # Place in first public subnet to ensure internet accessibility
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Ensure public IP is assigned
  root_block_device {
    volume_type           = "gp2"
    volume_size           = 30
    delete_on_termination = true
  }

  tags = {
    Name = "condensation-${var.environment}-app-ec2"
  }

  depends_on = [aws_internet_gateway.condensation]
}

# SSM Parameter for EC2 Instance ID
resource "aws_ssm_parameter" "ec2_instance_id" {
  name      = "/${var.environment}/ec2_instance_id"
  type      = "String"
  value     = aws_instance.app.id
  overwrite = true

  tags = {
    Name = "${var.environment}-ec2-instance-id"
  }

  depends_on = [aws_instance.app]
}

# SSM Parameter for EC2 public IP
resource "aws_ssm_parameter" "ec2_public_ip" {
  name      = "/${var.environment}/ec2_public_ip"
  type      = "String"
  value     = aws_instance.app.public_ip
  overwrite = true

  tags = {
    Name = "${var.environment}-ec2-public-ip"
  }

  depends_on = [aws_instance.app]
}

# SSM Parameter for EC2 secret key name
resource "aws_ssm_parameter" "ec2_secret_key_name" {
  name      = "/${var.environment}/ec2_secret_key_name"
  type      = "String"
  value     = aws_secretsmanager_secret.application_key.name
  overwrite = true

  tags = {
    Name = "${var.environment}-ec2-secret-key-name"
  }

  depends_on = [aws_instance.app]
}

# SSM Parameter for EC2 key pair name
resource "aws_ssm_parameter" "ec2_key_pair_name" {
  name      = "/${var.environment}/ec2_key_pair_name"
  type      = "String"
  value     = aws_key_pair.ec2_key.key_name
  overwrite = true

  tags = {
    Name = "${var.environment}-ec2-key-pair-name"
  }

  depends_on = [aws_instance.app]
}

# SSM Parameter for EC2 private IP
resource "aws_ssm_parameter" "ec2_private_ip" {
  name      = "/${var.environment}/ec2_private_ip"
  type      = "String"
  value     = aws_instance.app.private_ip
  overwrite = true

  tags = {
    Name = "${var.environment}-ec2-private-ip"
  }

  depends_on = [aws_instance.app]
}

# SSM Parameter for ECR Frontend URL
resource "aws_ssm_parameter" "ecr_frontend_url" {
  name      = "/${var.environment}/ecr_frontend_url"
  type      = "String"
  value     = aws_ecr_repository.frontend.repository_url
  overwrite = true

  tags = {
    Name = "${var.environment}-ecr-frontend-url"
  }

  depends_on = [aws_ecr_repository.frontend]
}

# SSM Parameter for ECR Backend URL
resource "aws_ssm_parameter" "ecr_backend_url" {
  name      = "/${var.environment}/ecr_backend_url"
  type      = "String"
  value     = aws_ecr_repository.backend.repository_url
  overwrite = true

  tags = {
    Name = "${var.environment}-ecr-backend-url"
  }

  depends_on = [aws_ecr_repository.backend]
}

# SSM Parameter for ECR Auth URL
resource "aws_ssm_parameter" "ecr_auth_url" {
  name      = "/${var.environment}/ecr_auth_url"
  type      = "String"
  value     = aws_ecr_repository.auth.repository_url
  overwrite = true

  tags = {
    Name = "${var.environment}-ecr-auth-url"
  }

  depends_on = [aws_ecr_repository.auth]
}

