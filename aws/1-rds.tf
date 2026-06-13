resource "aws_db_subnet_group" "postgres" {
  name       = "condensation-${var.environment}-postgres-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "condensation-${var.environment}-postgres-subnet-group"
  }
}

resource "aws_security_group" "rds_postgres" {
  name        = "condensation-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL instance (least privilege - EC2 only)"
  vpc_id      = aws_vpc.condensation.id

  # Only allow PostgreSQL from EC2 instance (least privilege)
  ingress {
    description     = "PostgreSQL from EC2 instance only"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # Minimal egress - RDS doesn't need to initiate outbound connections
  egress {
    description = "Allow minimal outbound (if needed)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "condensation-${var.environment}-rds-sg"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier = "${var.db_name}-db"

  engine         = "postgres"
  engine_version = "15"
  instance_class = var.db_instance_class

  publicly_accessible = false

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = replace(replace(var.db_name, "-", ""), "_", "")
  username = var.db_username
  port     = var.db_port

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds_postgres.id]

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.db_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  deletion_protection       = var.deletion_protection

  tags = {
    Name = "${var.environment}-${var.db_name}-db"
  }
}

resource "aws_ssm_parameter" "db_secret" {
  name  = "/${var.environment}/rds_db_secret"
  type  = "String"
  value = aws_db_instance.postgres.master_user_secret[0].secret_arn

  tags = {
    Name = "${var.environment}-db-parameter"
  }
}

# SSM Parameters for RDS connection details
resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "/${var.environment}/rds_endpoint"
  type  = "String"
  value = aws_db_instance.postgres.address

  tags = {
    Name = "${var.environment}-rds-endpoint"
  }
}

resource "aws_ssm_parameter" "rds_port" {
  name  = "/${var.environment}/rds_port"
  type  = "String"
  value = tostring(aws_db_instance.postgres.port)

  tags = {
    Name = "${var.environment}-rds-port"
  }
}

resource "aws_ssm_parameter" "rds_database_name" {
  name  = "/${var.environment}/rds_database_name"
  type  = "String"
  value = aws_db_instance.postgres.db_name

  tags = {
    Name = "${var.environment}-rds-database-name"
  }
}

# Alias for Ansible compatibility (Auth database)
resource "aws_ssm_parameter" "auth_database_name" {
  name  = "/${var.environment}/auth_database_name"
  type  = "String"
  value = aws_db_instance.postgres.db_name

  tags = {
    Name = "${var.environment}-auth-database-name"
  }
}

