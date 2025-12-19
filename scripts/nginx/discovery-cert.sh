#!/bin/bash

# Nome do container (pode ser passado como parâmetro)
CONTAINER="${1:-srv-nginx}"

# Executa o script dentro do container Docker
docker exec "$CONTAINER" sh -c '
# Array para armazenar os resultados (simulado com string)
results=""

# Função para extrair CN do subject
extract_cn() {
    local subject="$1"
    # Remove tudo antes de CN= e depois de , OU= ou fim da string
    echo "$subject" | sed -n "s/.*CN=\([^,]*\).*/\1/p" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//" | tr -d "\"" | tr -d "\\\\"
}

# Função para verificar se certificado não expirou
is_cert_valid() {
    local cert_file="$1"
    local expiry_date
    
    # Obtém a data de expiração do certificado
    expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    
    if [ -n "$expiry_date" ]; then
        # Converte para timestamp Unix
        local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null)
        local current_timestamp=$(date +%s)
        
        # Retorna 0 (verdadeiro) se o certificado ainda é válido
        [ "$expiry_timestamp" -gt "$current_timestamp" ]
    else
        return 1
    fi
}

# Procura certificados em /etc (como no seu script original)
find /etc -type f \( -name "*.crt" -o -name "*.pem" \) 2>/dev/null | while read -r cert_file; do
    # Verifica se o arquivo é um certificado válido
    if openssl x509 -in "$cert_file" -noout -text &>/dev/null; then
        # Extrai o subject do certificado
        subject=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed "s/subject=//")
        
        if [ -n "$subject" ]; then
            # Extrai o CN
            cn=$(extract_cn "$subject")
            
            # Verifica se o certificado ainda é válido (não expirou)
            if [ -n "$cn" ] && is_cert_valid "$cert_file"; then
                if [ -n "$results" ]; then
                    results="$results,"
                fi
                results="$results{\"#CERTCN\":\"$cn\"}"
            fi
        fi
    fi
done

# Imprime o resultado final em formato JSON
echo "{\"data\":[$results]}"
'