#!/bin/bash

# Carregar variáveis do arquivo .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Arquivo .env não encontrado!"
    exit 1
fi

# Variáveis de data
DATA_ATUAL=$(date +"%Y-%m-%d_%H-%M-%S")
DATA_ULTIMO_DIA_MES=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +"%Y-%m-%d")

# Pastas de destino
PASTA_GRAFANA="${HD_EXTERNO}/grafana/database"
PASTA_ZABBIX="${HD_EXTERNO}/zabbix/database"

# Criação das pastas, caso não existam
mkdir -p "$PASTA_GRAFANA"
mkdir -p "$PASTA_ZABBIX"

# Limpeza de backups antigos (mais de 7 dias), mas preservando o backup do último dia do mês
echo "Removendo backups antigos (mais de 7 dias, exceto o último dia do mês)..."
find "$PASTA_GRAFANA" -type f -name "*.sql" -mtime +7 ! -name "*${DATA_ULTIMO_DIA_MES}*" -exec rm -f {} \;
find "$PASTA_ZABBIX" -type f -name "*.sql" -mtime +7 ! -name "*${DATA_ULTIMO_DIA_MES}*" -exec rm -f {} \;

# Backup do banco do Grafana
echo "Iniciando backup do banco Grafana..."
docker exec "$CONTAINER_MYSQL" \
    mysqldump -u"$USER_MYSQL" -p"$PASSWORD_MYSQL" "$GRAFANA_DB" | gzip > \
    "${PASTA_GRAFANA}/grafana_backup_${DATA_ATUAL}.sql.gz"

if [ $? -eq 0 ]; then
    echo "Backup do Grafana concluído com sucesso: ${PASTA_GRAFANA}/grafana_backup_${DATA_ATUAL}.sql.gz"
else
    echo "Erro ao realizar backup do Grafana."e
fi

# Backup do banco do Zabbix
echo "Iniciando backup do banco Zabbix..."
docker exec "$CONTAINER_MYSQL" \
    mysqldump -u"$USER_MYSQL" -p"$PASSWORD_MYSQL" "$ZABBIX_DB" | gzip > \
    "${PASTA_ZABBIX}/zabbix_backup_${DATA_ATUAL}.sql.gz"

if [ $? -eq 0 ]; then
    echo "Backup do Zabbix concluído com sucesso: ${PASTA_ZABBIX}/zabbix_backup_${DATA_ATUAL}.sql.gz"
else
    echo "Erro ao realizar backup do Zabbix."
fi

# Backup especial do último dia do mês
if [ "$(date +%Y-%m-%d)" == "$DATA_ULTIMO_DIA_MES" ]; then
    echo "Backup especial do último dia do mês..."
    
    cp "${PASTA_GRAFANA}/grafana_backup_${DATA_ATUAL}.sql.gz" "${PASTA_GRAFANA}/grafana_backup_last_day_of_month_${DATA_ATUAL}.sql.gz"
    cp "${PASTA_ZABBIX}/zabbix_backup_${DATA_ATUAL}.sql.gz" "${PASTA_ZABBIX}/zabbix_backup_last_day_of_month_${DATA_ATUAL}.sql.gz"
    
    echo "Backup do último dia do mês salvo com sucesso."
fi


echo "Backup finalizado!"
