#!/bin/bash
set -euo pipefail

# Usage: import_csv.sh [csv_path] [db_name]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Carrega .env da raiz do projeto se existir
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ROOT_DIR/.env"
  set +a
fi

CSV_PATH="${1:-/data/csv/teste.csv}"
DB_NAME="${2:-login_domain}"
TABLE_NAME="login_domain"

MYSQL_HOST="${MYSQL_HOST:-}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"

if [[ -z "$MYSQL_PASSWORD" ]]; then
  echo "Erro: defina MYSQL_PASSWORD no ambiente." >&2
  exit 1
fi

if [[ ! -f "$CSV_PATH" ]]; then
  echo "Erro: CSV nao encontrado em: $CSV_PATH" >&2
  exit 1
fi

MYSQL_BASE_ARGS=(
  "--host=$MYSQL_HOST"
  "--port=$MYSQL_PORT"
  "--user=$MYSQL_USER"
  "--password=$MYSQL_PASSWORD"
  "--local-infile=1"
  "--protocol=tcp"
)

echo "Criando database/tabela se nao existir..."
mysql "${MYSQL_BASE_ARGS[@]}" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
mysql "${MYSQL_BASE_ARGS[@]}" "$DB_NAME" < "$SCRIPT_DIR/create_test_table.sql"

CSV_SQL_PATH="$(printf "%s" "$CSV_PATH" | sed "s/'/''/g")"

echo "Importando CSV com deduplicacao..."
mysql "${MYSQL_BASE_ARGS[@]}" "$DB_NAME" -e "
LOAD DATA LOCAL INFILE '${CSV_SQL_PATH}'
IGNORE INTO TABLE \`$TABLE_NAME\`
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\n'
(@datahora_raw, @usuario, @host, @ip, @serial)
SET
  datahora = STR_TO_DATE(REPLACE(REPLACE(@datahora_raw, '[', ''), ']', ''), '%d/%m/%Y %H:%i:%s'),
  usuario = @usuario,
  \`host\` = @host,
  ip = @ip,
  serial = REPLACE(@serial, '\r', ''),
  linha_hash = UNHEX(SHA2(CONCAT_WS('|', @datahora_raw, @usuario, @host, @ip, @serial), 256));
"

echo "Pronto. Linhas carregadas (duplicadas ignoradas pelo hash)."
