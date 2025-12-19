#!/bin/bash

# Configurações
ZABBIX_SERVER="172.18.0.3"
CONTAINERS=(
  ctr-cloudflare
  ctr-grafana
  ctr-haos
  ctr-mysql
  ctr-portainer02	
  ctr-utils
  ctr-zbx
  ctr-zbx-agent
  ctr-zbx-frontend	
)

# Função para converter valores para BYTES
convert_to_bytes() {
  local val=$(echo "$1" | sed 's/[^0-9\.]//g')
  local unit=$(echo "$1" | sed 's/[0-9.\ ]*//' | tr '[:upper:]' '[:lower:]')
  case "$unit" in
    gb|gib) echo "scale=0; $val * 1024 * 1024 * 1024" | bc ;;
    mb|mib) echo "scale=0; $val * 1024 * 1024" | bc ;;
    kb|kib) echo "scale=0; $val * 1024" | bc ;;
    b)      echo "$val" ;;
    *)      echo "0" ;;
  esac
}

# Coleta e envio
docker stats --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.BlockIO}}|{{.PIDs}}" |
while IFS="|" read -r name cpu mem netio blockio pids; do
  if [[ " ${CONTAINERS[*]} " == *" $name "* ]]; then

    # CPU
    cpu_value=$(echo "$cpu" | tr -d '%')

    # RAM
    mem_used_raw=$(echo "$mem" | awk '{print $1}')
    mem_used_bytes=$(convert_to_bytes "$mem_used_raw")

    # Net I/O
    rx=$(echo "$netio" | awk -F '/' '{print $1}' | xargs)
    tx=$(echo "$netio" | awk -F '/' '{print $2}' | xargs)

    # Block I/O
    rd=$(echo "$blockio" | awk -F '/' '{print $1}' | xargs)
    wr=$(echo "$blockio" | awk -F '/' '{print $2}' | xargs)

    rx_b=$(convert_to_bytes "$rx")
    tx_b=$(convert_to_bytes "$tx")
    rd_b=$(convert_to_bytes "$rd")
    wr_b=$(convert_to_bytes "$wr")

    # Envia tudo via zabbix_sender
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k system.cpu.util -o "$cpu_value"     > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k vm.memory.util  -o "$mem_used_bytes" > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k net.rx          -o "$rx_b"          > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k net.tx          -o "$tx_b"          > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k block.read      -o "$rd_b"          > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k block.write     -o "$wr_b"          > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k container.pids  -o "$pids"          > /dev/null

    echo "Enviado: $name | CPU: ${cpu_value}% | RAM: ${mem_used_bytes}B | RX: ${rx_b}B | TX: ${tx_b}B | RD: ${rd_b}B | WR: ${wr_b}B | PIDs: $pids"
  fi
done
