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
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.ec2_key.key_name
  iam_instance_profile   = "LabInstanceProfile"

  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = data.aws_subnets.default.ids[0]

  tags = {
    Name = "${var.environment}-app-ec2"
  }
}

# SSM Parameter for EC2 secret key name
resource "aws_ssm_parameter" "ec2_secret_key_name" {
  name  = "/${var.environment}/ec2_secret_key_name"
  type  = "String"
  value = aws_secretsmanager_secret.application_key.name

  tags = {
    Name = "${var.environment}-ec2-secret-key-name"
  }
}
