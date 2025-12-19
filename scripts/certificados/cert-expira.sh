#!/bin/bash

CONTAINER="srv-nginx"
TARGET_DOMAIN="$1"
CERT_PATH="/etc/letsencrypt/live"

if [ -z "$TARGET_DOMAIN" ]; then
    echo "-1"
    exit 1
fi

# Procura todos os diretórios de certificados
for dir in $(docker exec "$CONTAINER" find "$CERT_PATH" -maxdepth 1 -mindepth 1 -type d 2>/dev/null); do
    CERT_FILE="$dir/cert.pem"

    # Extrai SAN (Subject Alternative Name)
    DOMAIN=$(docker exec "$CONTAINER" openssl x509 -in "$CERT_FILE" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/.*DNS://;s/, DNS=/, /g')

    if [[ "$DOMAIN" == *"$TARGET_DOMAIN"* ]]; then
        EXP_DATE=$(docker exec "$CONTAINER" openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2)

        if [ -n "$EXP_DATE" ]; then
            EXP_TS=$(date -d "$EXP_DATE" +%s)
            NOW_TS=$(date +%s)
            DAYS_LEFT=$(( (EXP_TS - NOW_TS) / 86400 ))

            if [ "$DAYS_LEFT" -lt 0 ]; then
                echo "0"
            else
                echo "$DAYS_LEFT"
            fi
            exit 0
        fi
    fi
done

# Se não encontrar
echo "-1"
