# VPC and Network Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.condensation.id
}

output "vpc_name" {
  description = "VPC Name"
  value       = "condensation-${var.environment}-vpc"
}

output "public_subnet_1_id" {
  description = "Public Subnet 1 ID (AZ 1a)"
  value       = aws_subnet.public_1.id
}

output "public_subnet_2_id" {
  description = "Public Subnet 2 ID (AZ 1b)"
  value       = aws_subnet.public_2.id
}

output "private_subnet_1_id" {
  description = "Private Subnet 1 ID for RDS (AZ 1a)"
  value       = aws_subnet.private_1.id
}

output "private_subnet_2_id" {
  description = "Private Subnet 2 ID for RDS (AZ 1b)"
  value       = aws_subnet.private_2.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.condensation.id
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "rds_master_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master password"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "rds_game_address" {
  description = "RDS instance address"
  value       = aws_db_instance.postgres.address
}


output "rds_game_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres_game.port
}




# ECR Outputs
output "ecr_frontend_repository_url" {
  description = "URL of the ECR repository for frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_frontend_repository_arn" {
  description = "ARN of the ECR repository for frontend"
  value       = aws_ecr_repository.frontend.arn
}

output "ecr_backend_repository_url" {
  description = "URL of the ECR repository for backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_backend_repository_arn" {
  description = "ARN of the ECR repository for backend"
  value       = aws_ecr_repository.backend.arn
}

output "ecr_auth_repository_url" {
  description = "URL of the ECR repository for frontend"
  value       = aws_ecr_repository.auth.repository_url
}

output "ecr_auth_repository_arn" {
  description = "ARN of the ECR repository for frontend"
  value       = aws_ecr_repository.auth.arn
}



# EC2 Outputs
output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "ec2_instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "ec2_instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.app.private_ip
}

output "ec2_key_pair_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.ec2_key.key_name
}

output "ec2_security_group_id" {
  description = "Security Group ID for EC2"
  value       = aws_security_group.ec2.id
}

output "ec2_security_group_name" {
  description = "Security Group name for EC2"
  value       = aws_security_group.ec2.name
}

output "ec2_instance_name" {
  description = "Name of the EC2 instance"
  value       = "condensation-${var.environment}-app-ec2"
}

output "ec2_secret_key_arn" {
  description = "ARN of the Secrets Manager secret containing the private key"
  value       = aws_secretsmanager_secret.application_key.arn
}

output "ec2_secret_key_name" {
  description = "Name of the Secrets Manager secret containing the private key"
  value       = aws_secretsmanager_secret.application_key.name
}

# SSM Parameter Store Outputs
output "ssm_db_parameter_name" {
  description = "Name of the SSM parameter for RDS secret ARN"
  value       = aws_ssm_parameter.db_secret.name
}

# EC2 SSM Parameters
output "ssm_ec2_instance_id" {
  description = "SSM Parameter name for EC2 instance ID"
  value       = aws_ssm_parameter.ec2_instance_id.name
}

output "ssm_ec2_public_ip" {
  description = "SSM Parameter name for EC2 public IP"
  value       = aws_ssm_parameter.ec2_public_ip.name
}

output "ssm_ec2_private_ip" {
  description = "SSM Parameter name for EC2 private IP"
  value       = aws_ssm_parameter.ec2_private_ip.name
}

output "ssm_ec2_secret_key_name" {
  description = "SSM Parameter name for EC2 secret key name"
  value       = aws_ssm_parameter.ec2_secret_key_name.name
}

output "ssm_ec2_key_pair_name" {
  description = "SSM Parameter name for EC2 key pair name"
  value       = aws_ssm_parameter.ec2_key_pair_name.name
}

# ECR URLs SSM Parameters
output "ssm_ecr_frontend_url" {
  description = "SSM Parameter name for ECR Frontend URL"
  value       = aws_ssm_parameter.ecr_frontend_url.name
}

output "ssm_ecr_backend_url" {
  description = "SSM Parameter name for ECR Backend URL"
  value       = aws_ssm_parameter.ecr_backend_url.name
}

output "ssm_ecr_auth_url" {
  description = "SSM Parameter name for ECR Auth URL"
  value       = aws_ssm_parameter.ecr_auth_url.name
}
