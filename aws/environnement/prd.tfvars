# Environment Configuration
environment = "prd"

# RDS Configuration
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_name              = "app-prd"
db_username          = "user_prd"

db_game_instance_class    = "db.t3.micro"
db_game_allocated_storage = 20
db_game_name              = "app-prd"
db_game_username          = "user_prd"



backup_retention_period = 30
skip_final_snapshot     = true
deletion_protection     = true

allowed_cidr_blocks = []


