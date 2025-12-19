#!/bin/bash

CONFIG_PATH="/root/.config/ookla/speedtest-cli.json"

# Aceita licença do Speedtest (só se ainda não existir)
mkdir -p "$(dirname "$CONFIG_PATH")"

if [ ! -f "$CONFIG_PATH" ]; then
    echo "Registrando aceite da licença do speedtest..."
    cat <<EOF > "$CONFIG_PATH"
{
  "LicenseAccepted": true,
  "Settings": {
    "LicenseAccepted": "604ec27f828456331ebf441826292c49276bd3c1bee1a2f65a6452f505c4061c",
    "GDPRTimeStamp": $(date +%s)
  }
}
EOF
fi

echo "Iniciando cron em foreground..."

touch /var/log/cron.log

# Mantém o container vivo executando o cron
exec cron -f
