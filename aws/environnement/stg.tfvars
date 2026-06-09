# Environment Configuration
environment = "stg"

# RDS Configuration
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_name              = "app-stg"
db_username          = "user_stg"

db_game_instance_class    = "db.t3.micro"
db_game_allocated_storage = 20
db_game_name              = "app-stg"
db_game_username          = "user_stg"

backup_retention_period = 7
skip_final_snapshot     = true
deletion_protection     = false

allowed_cidr_blocks = []
