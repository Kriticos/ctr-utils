#!/bin/bash

CONTAINER="srv-nginx"

echo "Verificando certificados no container: $CONTAINER"
echo "==============================================="

docker exec "$CONTAINER" sh -c '
find /etc -type f \( -name "*.crt" -o -name "*.pem" \) 2>/dev/null |
while read -r cert; do
    echo "Certificado: $cert"
    openssl x509 -in "$cert" -noout -subject -enddate 2>/dev/null || echo "Erro ao ler o certificado"
    echo "-----------------------------------------------"
done
'
