#!/bin/bash

echo "📁 Iniciando preparação das pastas do ambiente..."

# Detecta o diretório base automaticamente
BASE_DIR="$(dirname "$(realpath "$0")")"

# Pastas de dados (volumes persistentes)
DATA_DIRS=(
  "$BASE_DIR/scripts"
  "$BASE_DIR/cron"
)

# Pastas de backups
BACKUP_DIRS=(
  "$BASE_DIR/backups"
)

# Criando diretórios
for DIR in "${DATA_DIRS[@]}" "${DATABASES_DIRS[@]}" "${BACKUP_DIRS[@]}"; do
  if [ ! -d "$DIR" ]; then
    echo "📂 Criando $DIR"
    mkdir -p "$DIR"
  else
    echo "✔️ Já existe: $DIR"
  fi
done

echo "🔧 Ajustando permissões..."
chmod +x "$BASE_DIR/scripts/"*.sh

# Configurando rede Docker personalizada
if ! docker network ls | grep -q "network-share"; then
  echo "Criando rede network-share..."
  docker network create \
    --driver=bridge \
    --subnet=172.18.0.0/16 \
    network-share
fi

echo "✅ Preparação concluída!"