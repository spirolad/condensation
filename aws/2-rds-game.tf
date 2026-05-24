resource "aws_db_subnet_group" "postgres_game" {
  name       = "${var.db_game_name}-sbnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "${var.environment}-${var.db_game_name}-subnet-group"
  }
}

resource "aws_security_group" "rds_game_postgres" {
  name        = "${var.db_game_name}-rds-game-sg"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL from EC2 security group"
    from_port       = var.db_game_port
    to_port         = var.db_game_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  ingress {
    description     = "PostgreSQL from user IP"
    from_port       = var.db_game_port
    to_port         = var.db_game_port
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.db_game_name}-rds-game-sg"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres_game" {
  identifier = "${var.db_game_name}-db-game"

  engine         = "postgres"
  engine_version = "15"
  instance_class = var.db_game_instance_class

  publicly_accessible = true

  allocated_storage     = var.db_game_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = replace(replace(var.db_game_name, "-", ""), "_", "")
  username = var.db_game_username
  port     = var.db_game_port

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres_game.name
  vpc_security_group_ids = [aws_security_group.rds_game_postgres.id]

  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

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
  value = aws_db_instance.postgres.address

  tags = {
    Name = "${var.environment}-rds-game-endpoint"
  }
}

resource "aws_ssm_parameter" "rds_game_port" {
  name  = "/${var.environment}/rds_game_port"
  type  = "String"
  value = tostring(aws_db_instance.postgres.port)

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

