#!/bin/bash

# Variáveis
data_atual=$(date +"%Y-%m-%d_%H-%M-%S")
diretorios_origem=("/bskp/docker" "/bskp/grafana" "/bskp/scripts" "/bskp/zabbix" "/bskp/README.md" "/bskp/mysql")  
diretorio_destino="/media/kriticos/bskp/bkp/bskp"

# Criar backup para cada diretório
echo "Iniciando backup das pastas selecionadas..."
for origem in "${diretorios_origem[@]}"; do
    nome_pasta=$(basename "$origem")  # Obtém apenas o nome da pasta
    destino_pasta="${diretorio_destino}/${nome_pasta}"  # Define a pasta de destino
    arquivo_bkp="${destino_pasta}/bkp_${nome_pasta}_${data_atual}.tar.gz"  # Nome do arquivo de backup

    # Criar a pasta de destino, caso não exista
    mkdir -p "$destino_pasta"

    # Criar o backup
    tar -czf "$arquivo_bkp" "$origem"
    if [ $? -eq 0 ]; then
        echo "Backup concluído para: $origem -> $arquivo_bkp"
    else
        echo "Erro ao realizar o backup de $origem"
    fi

    # Remover backups mais antigos que 7 dias dentro da pasta específica
    find "$destino_pasta" -type f -name "*.tar.gz" -mtime +7 -exec rm -f {} \;
done

echo "Backup finalizado!"
