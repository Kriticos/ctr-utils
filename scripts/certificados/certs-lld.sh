#!/bin/bash

CONTAINER="srv-nginx"
CERT_PATH="/etc/letsencrypt/live"

echo "{"
echo "    \"data\": ["

FIRST=true
for DIR in $(docker exec "$CONTAINER" find "$CERT_PATH" -maxdepth 1 -mindepth 1 -type d 2>/dev/null); do
    CERT_FILE="$DIR/cert.pem"
    
    # Verifica se o arquivo cert.pem existe
    if docker exec "$CONTAINER" test -f "$CERT_FILE" 2>/dev/null; then
        # Extrai o primeiro domínio do SAN (Subject Alternative Name)
        DOMAIN=$(docker exec "$CONTAINER" openssl x509 -in "$CERT_FILE" -noout -text 2>/dev/null \
            | grep -A1 "Subject Alternative Name" \
            | tail -1 \
            | sed 's/.*DNS://;s/, DNS:.*//')
        
        # Se não encontrou SAN, tenta pegar do Subject CN
        if [ -z "$DOMAIN" ]; then
            DOMAIN=$(docker exec "$CONTAINER" openssl x509 -in "$CERT_FILE" -noout -subject 2>/dev/null \
                | sed 's/.*CN = //;s/,.*//')
        fi
        
        # Se ainda não encontrou, usa o nome do diretório
        if [ -z "$DOMAIN" ]; then
            DOMAIN=$(basename "$DIR")
        fi
        
        # Só adiciona se o domínio não estiver vazio
        if [ -n "$DOMAIN" ]; then
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                echo ","
            fi
            
            echo "     {"
            echo "     \"{#CERTCN}\": \"$DOMAIN\""
            echo -n "    }"
        fi
    fi
done

echo
echo "   ]"
echo " }"
