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

CSV_PATH="${1:-$ROOT_DIR/csv/teste.csv}"
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

if [[ "$DB_NAME" =~ ^- ]]; then
  echo "Erro: DB_NAME nao pode iniciar com '-'." >&2
  exit 1
fi

if [[ ! "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "Erro: DB_NAME contem caracteres invalidos. Use apenas [A-Za-z0-9_]." >&2
  exit 1
fi

if [[ ! -f "$CSV_PATH" ]]; then
  echo "Erro: CSV nao encontrado em: $CSV_PATH" >&2
  exit 1
fi

USE_DOCKER_MYSQL=0
if ! command -v mysql >/dev/null 2>&1; then
  if command -v docker >/dev/null 2>&1; then
    USE_DOCKER_MYSQL=1
  else
    echo "Erro: mysql nao encontrado no PATH e docker indisponivel." >&2
    echo "Instale o cliente mysql ou rode com docker disponivel." >&2
    exit 1
  fi
fi

MYSQL_BASE_ARGS_HOST=(
  "--host=$MYSQL_HOST"
  "--port=$MYSQL_PORT"
  "--user=$MYSQL_USER"
  "--local-infile=1"
  "--protocol=tcp"
)

MYSQL_BASE_ARGS_CONTAINER=(
  "--user=$MYSQL_USER"
  "--local-infile=1"
)

run_mysql() {
  if [[ "$USE_DOCKER_MYSQL" -eq 1 ]]; then
    docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" ctr-mysql mysql "${MYSQL_BASE_ARGS_CONTAINER[@]}" "$@"
  else
    MYSQL_PWD="$MYSQL_PASSWORD" mysql "${MYSQL_BASE_ARGS_HOST[@]}" "$@"
  fi
}

CSV_CONTAINER_PATH="$CSV_PATH"
CSV_CONTAINER_CREATED=0

if [[ "$USE_DOCKER_MYSQL" -eq 1 ]]; then
  CSV_CONTAINER_PATH="/tmp/import_csv_${$}_$RANDOM.csv"
  docker cp "$CSV_PATH" "ctr-mysql:$CSV_CONTAINER_PATH"
  CSV_CONTAINER_CREATED=1
fi

CSV_SQL_PATH="$(printf "%s" "$CSV_CONTAINER_PATH" | sed "s/'/''/g")"

echo "Importando CSV com deduplicacao..."
cleanup_container_csv() {
  if [[ "$USE_DOCKER_MYSQL" -eq 1 && "$CSV_CONTAINER_CREATED" -eq 1 ]]; then
    docker exec -i ctr-mysql rm -f "$CSV_CONTAINER_PATH"
  fi
}

trap cleanup_container_csv EXIT

run_mysql "$DB_NAME" -e "
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
