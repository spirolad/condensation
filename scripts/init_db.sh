#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment>" >&2
  exit 2
fi

ENV="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_FILE="$ROOT_DIR/scripts/V1__create_game_catalog_schema.sql"
SEED_FILE="$ROOT_DIR/scripts/seed_games.sql"

for cmd in aws jq psql; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 3
  fi
done

echo "Fetching RDS connection info from SSM..."
endpoint=$(aws ssm get-parameter --name "/${ENV}/rds_game_endpoint" --query Parameter.Value --output text)
port=$(aws ssm get-parameter --name "/${ENV}/rds_game_port" --query Parameter.Value --output text)
dbname=$(aws ssm get-parameter --name "/${ENV}/rds_database_game_name" --query Parameter.Value --output text)
secret_arn=$(aws ssm get-parameter --name "/${ENV}/rds_db_game_secret" --query Parameter.Value --output text)

if [ -z "$endpoint" ] || [ -z "$port" ] || [ -z "$dbname" ] || [ -z "$secret_arn" ]; then
  echo "Missing connection information in SSM for environment ${ENV}" >&2
  exit 4
fi

echo "Retrieving DB credentials from Secrets Manager..."
secret_json=$(aws secretsmanager get-secret-value --secret-id "$secret_arn" --query SecretString --output text)
if [ -z "$secret_json" ]; then
  echo "Failed to retrieve secret value" >&2
  exit 5
fi

db_user=$(printf '%s' "$secret_json" | jq -r .username)
db_pass=$(printf '%s' "$secret_json" | jq -r .password)

if [ -z "$db_user" ] || [ -z "$db_pass" ]; then
  echo "Secret JSON did not contain username/password" >&2
  exit 6
fi

export PGPASSWORD="$db_pass"

echo "Initializing schema: $SCHEMA_FILE"
psql -h "$endpoint" -p "$port" -U "$db_user" -d "$dbname" -v ON_ERROR_STOP=1 -f "$SCHEMA_FILE"

echo "Seeding data: $SEED_FILE"
psql -h "$endpoint" -p "$port" -U "$db_user" -d "$dbname" -v ON_ERROR_STOP=1 -f "$SEED_FILE"

echo "Database initialization complete."
