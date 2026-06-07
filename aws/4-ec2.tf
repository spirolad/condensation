# TLS Private Key
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# AWS Secrets Manager Secret for the private key
resource "aws_secretsmanager_secret" "application_key" {
  name = "${var.environment}-app-secretkey"
  
  tags = {
    Name        = "${var.environment}-app-secretkey"
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

# Security Group for EC2
resource "aws_security_group" "ec2" {
  name        = "${var.environment}-ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Frontend"
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backend"
    from_port   = 8080
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "auth"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }



  ingress {
    description = "NodeExporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-ec2-sg"
  }
}

# EC2 Instance
resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.ec2_instance_type
  key_name                    = aws_key_pair.ec2_key.key_name
  iam_instance_profile        = "LabInstanceProfile"
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = data.aws_subnets.default.ids[1]

  tags = {
    Name = "${var.environment}-app-ec2"
  }
}

# SSM Parameter for EC2 Instance ID
resource "aws_ssm_parameter" "ec2_instance_id" {
  name  = "/${var.environment}/ec2_instance_id"
  type  = "String"
  value = aws_instance.app.id

  tags = {
    Name = "${var.environment}-ec2-instance-id"
  }

  depends_on = [aws_instance.app]
}

# SSM Parameter for EC2 public IP
resource "aws_ssm_parameter" "ec2_public_ip" {
  name  = "/${var.environment}/ec2_public_ip"
  type  = "String"
  value = aws_instance.app.public_ip

  tags = {
    Name = "${var.environment}-ec2-public-ip"
  }

  depends_on = [aws_instance.app]
}

# SSM Parameter for EC2 secret key name
resource "aws_ssm_parameter" "ec2_secret_key_name" {
  name  = "/${var.environment}/ec2_secret_key_name"
  type  = "String"
  value = aws_secretsmanager_secret.application_key.name

  tags = {
    Name = "${var.environment}-ec2-secret-key-name"
  }

  depends_on = [aws_instance.app]
}

# SSM Parameter for EC2 key pair name
resource "aws_ssm_parameter" "ec2_key_pair_name" {
  name  = "/${var.environment}/ec2_key_pair_name"
  type  = "String"
  value = aws_key_pair.ec2_key.key_name

  tags = {
    Name = "${var.environment}-ec2-key-pair-name"
  }

  depends_on = [aws_instance.app]
}

# SSM Parameter for EC2 private IP
resource "aws_ssm_parameter" "ec2_private_ip" {
  name  = "/${var.environment}/ec2_private_ip"
  type  = "String"
  value = aws_instance.app.private_ip

  tags = {
    Name = "${var.environment}-ec2-private-ip"
  }

  depends_on = [aws_instance.app]
}

# SSM Parameter for ECR Frontend URL
resource "aws_ssm_parameter" "ecr_frontend_url" {
  name  = "/${var.environment}/ecr_frontend_url"
  type  = "String"
  value = aws_ecr_repository.frontend.repository_url

  tags = {
    Name = "${var.environment}-ecr-frontend-url"
  }

  depends_on = [aws_ecr_repository.frontend]
}

# SSM Parameter for ECR Backend URL
resource "aws_ssm_parameter" "ecr_backend_url" {
  name  = "/${var.environment}/ecr_backend_url"
  type  = "String"
  value = aws_ecr_repository.backend.repository_url

  tags = {
    Name = "${var.environment}-ecr-backend-url"
  }

  depends_on = [aws_ecr_repository.backend]
}

# SSM Parameter for ECR Auth URL
resource "aws_ssm_parameter" "ecr_auth_url" {
  name  = "/${var.environment}/ecr_auth_url"
  type  = "String"
  value = aws_ecr_repository.auth.repository_url

  tags = {
    Name = "${var.environment}-ecr-auth-url"
  }

  depends_on = [aws_ecr_repository.auth]
}

