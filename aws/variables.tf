# AWS Provider Variables
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# RDS Variables
variable "db_instance_class" {
  description = "Instance class for RDS PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "postgres"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Port for PostgreSQL"
  type        = number
  default     = 5433
}

# RDS game

variable "db_game_instance_class" {
  description = "Instance class for RDS PostgreSQL"
  type        = string
  default     = "db_game.t3.micro"
}

variable "db_game_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_game_name" {
  description = "Name of the database"
  type        = string
  default     = "postgres"
}

variable "db_game_username" {
  description = "Master username for the database"
  type        = string
  sensitive   = true
}

variable "db_game_port" {
  description = "Port for PostgreSQL"
  type        = number
  default     = 5434
}



variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access RDS"
  type        = list(string)
  default     = []
}

variable "backup_retention_period" {
  description = "The number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "The database can't be deleted when this value is set to true"
  type        = bool
  default     = false
}

# Environment Variables
variable "environment" {
  description = "Environment name (e.g., prd, dev, staging)"
  type        = string
  default     = "dev"
}

# CI/CD Variables
variable "app_version" {
  description = "Version of the deployment (CI_COMMIT_REF_SLUG-CI_COMMIT_SHORT_SHA)"
  type        = string
  default     = "unknown"
}

variable "user" {
  description = "GitLab user who triggered the deployment"
  type        = string
  default     = "unknown"
}

variable "commit" {
  description = "Git commit SHA"
  type        = string
  default     = "unknown"
}

variable "branch" {
  description = "Git branch name"
  type        = string
  default     = "unknown"
}

# EC2 Variables
variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

