resource "aws_db_subnet_group" "postgres_game" {
  name       = "condensation-${var.environment}-game-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "condensation-${var.environment}-game-subnet-group"
  }
}

resource "aws_security_group" "rds_game_postgres" {
  name        = "condensation-${var.environment}-game-rds-sg"
  description = "Security group for RDS PostgreSQL game instance (least privilege - EC2 only)"
  vpc_id      = aws_vpc.condensation.id

  # Only allow PostgreSQL from EC2 instance (least privilege)
  ingress {
    description     = "PostgreSQL from EC2 instance only"
    from_port       = var.db_game_port
    to_port         = var.db_game_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # Minimal egress
  egress {
    description = "Allow minimal outbound (if needed)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "condensation-${var.environment}-game-rds-sg"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres_game" {
  identifier = "${var.db_game_name}-db-game"

  engine         = "postgres"
  engine_version = "15"
  instance_class = var.db_game_instance_class

  publicly_accessible = false

  allocated_storage = var.db_game_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = replace(replace(var.db_game_name, "-", ""), "_", "")
  username = var.db_game_username
  port     = var.db_game_port

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres_game.name
  vpc_security_group_ids = [aws_security_group.rds_game_postgres.id]

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.db_game_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  deletion_protection       = var.deletion_protection

  tags = {
    Name = "${var.environment}-${var.db_game_name}-db_game"
  }
}

resource "aws_ssm_parameter" "db_game_secret" {
  name  = "/${var.environment}/rds_db_game_secret"
  type  = "String"
  value = aws_db_instance.postgres_game.master_user_secret[0].secret_arn

  tags = {
    Name = "${var.environment}-db_game-parameter"
  }
}

# SSM Parameters for RDS connection details
resource "aws_ssm_parameter" "rds_game_endpoint" {
  name  = "/${var.environment}/rds_game_endpoint"
  type  = "String"
  value = aws_db_instance.postgres_game.address

  tags = {
    Name = "${var.environment}-rds-game-endpoint"
  }
}

resource "aws_ssm_parameter" "rds_game_port" {
  name  = "/${var.environment}/rds_game_port"
  type  = "String"
  value = tostring(aws_db_instance.postgres_game.port)

  tags = {
    Name = "${var.environment}-rds-game-port"
  }
}

resource "aws_ssm_parameter" "rds_database_game_name" {
  name  = "/${var.environment}/rds_database_game_name"
  type  = "String"
  value = aws_db_instance.postgres_game.db_name

  tags = {
    Name = "${var.environment}-rds-database-game-name"
  }
}

# Alias for Ansible compatibility (Game database)
resource "aws_ssm_parameter" "game_database_name" {
  name  = "/${var.environment}/game_database_name"
  type  = "String"
  value = aws_db_instance.postgres_game.db_name

  tags = {
    Name = "${var.environment}-game-database-name"
  }
}

# Local provisioner: run DB initialization script after the RDS instance is available.
resource "null_resource" "init_db_game" {
  # Re-run when the instance identifier changes
  triggers = {
    db_instance_identifier = aws_db_instance.postgres_game.identifier
  }

  depends_on = [aws_db_instance.postgres_game]

  provisioner "local-exec" {
    command = "bash \"${path.root}/scripts/init_db.sh\" \"${var.environment}\""
  }
}

