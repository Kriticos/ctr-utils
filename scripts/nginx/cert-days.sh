#!/bin/bash

# Parâmetros
CN="$1"
CONTAINER="${2:-ctr-nginx}"

# Verifica se o CN foi fornecido
if [ -z "$CN" ]; then
    echo "Uso: $0 <CN_do_certificado> [nome_do_container]"
    echo "Exemplo: $0 'exemplo.com' 'srv-nginx'"
    exit 1
fi

# Limpa o CN para evitar problemas com aspas e escapes
CN=$(echo "$CN" | tr -d '"' | tr -d "'")

# Executa a busca dentro do container Docker
result=$(docker exec "$CONTAINER" sh -c "
# Função para extrair CN do subject
extract_cn() {
    local subject=\"\$1\"
    echo \"\$subject\" | sed -n 's/.*CN=\([^,]*\).*/\1/p' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\"' | tr -d '\\\\'
}

# Função para calcular dias até expiração
calculate_days() {
    local cert_file=\"\$1\"
    local expiry_date
    
    # Obtém a data de expiração do certificado
    expiry_date=\$(openssl x509 -in \"\$cert_file\" -noout -enddate 2>/dev/null | cut -d= -f2)
    
    if [ -n \"\$expiry_date\" ]; then
        # Converte para timestamp Unix
        local expiry_timestamp=\$(date -d \"\$expiry_date\" +%s 2>/dev/null)
        local current_timestamp=\$(date +%s)
        
        # Calcula a diferença em dias
        local diff_seconds=\$((expiry_timestamp - current_timestamp))
        local days=\$((diff_seconds / 86400))
        
        echo \"\$days\"
    else
        echo \"-1\"
    fi
}

# CN buscado
target_cn='$CN'
found_cert=''
days_result='-1'

# Procura certificados em /etc (exclui chaves privadas)
find /etc -type f \( -name '*.crt' -o -name '*.pem' \) 2>/dev/null | grep -v 'privkey' | while read -r cert_file; do
    # Verifica se o arquivo é um certificado válido (suprime erros)
    if openssl x509 -in \"\$cert_file\" -noout -text >/dev/null 2>&1; then
        # Extrai o subject do certificado
        subject=\$(openssl x509 -in \"\$cert_file\" -noout -subject 2>/dev/null | sed 's/subject=//')
        
        if [ -n \"\$subject\" ]; then
            # Extrai o CN
            cn=\$(extract_cn \"\$subject\")
            
            if [ -n \"\$cn\" ]; then
                # Primeira tentativa: correspondência exata
                if [ \"\$cn\" = \"\$target_cn\" ]; then
                    days=\$(calculate_days \"\$cert_file\")
                    echo \"\$days\"
                    exit 0
                fi
            fi
        fi
    fi
done

# Se não encontrou correspondência exata, tenta com correspondência parcial
find /etc -type f \( -name '*.crt' -o -name '*.pem' \) 2>/dev/null | grep -v 'privkey' | while read -r cert_file; do
    if openssl x509 -in \"\$cert_file\" -noout -text &>/dev/null; then
        subject=\$(openssl x509 -in \"\$cert_file\" -noout -subject 2>/dev/null | sed 's/subject=//')
        
        if [ -n \"\$subject\" ]; then
            cn=\$(extract_cn \"\$subject\")
            
            if [ -n \"\$cn\" ]; then
                # Segunda tentativa: correspondência parcial (like)
                case \"\$cn\" in
                    *\$target_cn*)
                        days=\$(calculate_days \"\$cert_file\")
                        echo \"\$days\"
                        exit 0
                        ;;
                esac
            fi
        fi
    fi
done

# Se ainda não encontrou, tenta uma abordagem mais flexível com regex
find /etc -type f \( -name '*.crt' -o -name '*.pem' \) 2>/dev/null | grep -v 'privkey' | while read -r cert_file; do
    if openssl x509 -in \"\$cert_file\" -noout -text &>/dev/null; then
        subject=\$(openssl x509 -in \"\$cert_file\" -noout -subject 2>/dev/null | sed 's/subject=//')
        
        if [ -n \"\$subject\" ]; then
            # Terceira tentativa: busca com regex mais flexível
            if echo \"\$subject\" | grep -q \"CN=.*\$target_cn\"; then
                days=\$(calculate_days \"\$cert_file\")
                echo \"\$days\"
                exit 0
            fi
        fi
    fi
done

# Se chegou até aqui, não encontrou o certificado
echo '-1'
")

# Pega apenas a primeira linha do resultado (caso haja múltiplas saídas)
final_result=$(echo "$result" | head -n1)

# Se o resultado estiver vazio, retorna -1
if [ -z "$final_result" ]; then
    echo "-1"
else
    echo "$final_result"
fi