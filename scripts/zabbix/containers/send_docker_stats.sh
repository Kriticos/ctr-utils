#!/bin/bash

# =======================
# CONFIGURAÇÕES
# =======================
ZABBIX_SERVER="172.18.0.3"

CONTAINERS=(
  ctr-cloudflare-PRO
  ctr-grafana-PRO
  ctr-haos-PRO
  ctr-mysql-PRO
  ctr-portainer-PRO
  ctr-utils-PRO
  ctr-zbx-PRO
  ctr-zbx-agent-PRO
  ctr-zbx-frontend-PRO
)

# =======================
# FUNÇÃO: CONVERTER PARA BYTES
# =======================
convert_to_bytes() {
  local val unit
  val=$(echo "$1" | sed 's/[^0-9\.]//g')
  unit=$(echo "$1" | sed 's/[0-9.\ ]*//' | tr '[:upper:]' '[:lower:]')

  [ -z "$val" ] && echo 0 && return

  case "$unit" in
    gb|gib) echo "$val * 1024 * 1024 * 1024" | bc ;;
    mb|mib) echo "$val * 1024 * 1024" | bc ;;
    kb|kib) echo "$val * 1024" | bc ;;
    b|"")   echo "$val" ;;
    *)      echo 0 ;;
  esac
}

# =======================
# COLETA E ENVIO
# =======================
docker stats --no-stream \
--format "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.BlockIO}}|{{.PIDs}}" |
while IFS="|" read -r name cpu mem netio blockio pids; do

  if [[ " ${CONTAINERS[*]} " == *" $name "* ]]; then

    # -----------------------
    # CPU (%)
    # -----------------------
    cpu_value=$(echo "$cpu" | tr -d '%')

    # -----------------------
    # MEMÓRIA (BYTES)
    # -----------------------
    mem_used_raw=$(echo "$mem" | awk '{print $1}')
    mem_used_bytes=$(convert_to_bytes "$mem_used_raw")

    # -----------------------
    # NETWORK (BYTES)
    # -----------------------
    rx_raw=$(echo "$netio" | awk -F '/' '{print $1}' | xargs)
    tx_raw=$(echo "$netio" | awk -F '/' '{print $2}' | xargs)

    rx_b=$(convert_to_bytes "$rx_raw")
    tx_b=$(convert_to_bytes "$tx_raw")

    # -----------------------
    # BLOCK I/O (BYTES)
    # -----------------------
    rd_raw=$(echo "$blockio" | awk -F '/' '{print $1}' | xargs)
    wr_raw=$(echo "$blockio" | awk -F '/' '{print $2}' | xargs)

    rd_b=$(convert_to_bytes "$rd_raw")
    wr_b=$(convert_to_bytes "$wr_raw")

    # -----------------------
    # ENVIO ZABBIX
    # -----------------------
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k container.cpu.util              -o "$cpu_value"     > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k container.memory.util           -o "$mem_used_bytes" > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k container.net.rx.bytes          -o "$rx_b"           > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k container.net.tx.bytes          -o "$tx_b"           > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k container.disk.read.bytes       -o "$rd_b"           > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k container.disk.write.bytes      -o "$wr_b"           > /dev/null
    zabbix_sender -z "$ZABBIX_SERVER" -s "$name" -k container.pids                  -o "$pids"           > /dev/null

    echo "Enviado: $name | CPU=${cpu_value}% | RAM=${mem_used_bytes}B | RX=${rx_b}B | TX=${tx_b}B | RD=${rd_b}B | WR=${wr_b}B | PIDs=$pids"
  fi
done
