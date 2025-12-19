#!/bin/bash

# -------------------------------------------------------------------
# Monitoramento de Conectividade — Zabbix Sender
# Versão: 2.1 (Revisado e otimizado)
# Autor: Kriticos (Ambiente Docker ctr-tools)
# -------------------------------------------------------------------

# Configurações do Zabbix
ZBX_HOST="Link - Internet"
ZBX_SERVER="172.18.0.3"
LOG_FILE="/var/log/connectivity_check.log"

# Parâmetros
PING_COUNT=3
PING_TIMEOUT=2
CURL_TIMEOUT=5
MAX_RETRIES=2

# Alvos
GATEWAYS=$(ip route | awk '/default/ {print $3}')
DNS_SERVERS=("8.8.8.8" "1.1.1.1")
TEST_URLS=("https://www.google.com" "https://www.cloudflare.com" "https://www.microsoft.com")

# -------------------------------------------------------------------
# Função de Log
# -------------------------------------------------------------------
log_msg() {
    local level=$1
    local msg=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $msg" | tee -a "$LOG_FILE"
}

# -------------------------------------------------------------------
# Checagem de Ferramentas
# -------------------------------------------------------------------
check_tools() {
    REQUIRED_TOOLS=(
        "ping"
        "curl"
        "nslookup"
        "zabbix_sender"
        "ip"
    )

    log_msg "INFO" "Verificando dependências do sistema..."

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_msg "ERROR" "Ferramenta obrigatória ausente: $tool"
            exit 1
        fi
    done

    log_msg "INFO" "Todas as dependências estão presentes."
}

# -------------------------------------------------------------------
# Envio ao Zabbix
# -------------------------------------------------------------------
send_to_zabbix() {
    local level=$1
    local description=$2

    log_msg "INFO" "Enviando status ao Zabbix: Nível $level — $description"

    zabbix_sender -z "$ZBX_SERVER" -s "$ZBX_HOST" -k check.connectivity.level -o "$level" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_msg "INFO" "Dados enviados com sucesso ao Zabbix."
    else
        log_msg "ERROR" "Falha ao enviar dados ao Zabbix Server ($ZBX_SERVER)."
    fi
}

# -------------------------------------------------------------------
# Teste 1 — Gateway
# -------------------------------------------------------------------
test_gateway() {
    log_msg "INFO" "Testando conectividade com gateway..."

    for gw in $GATEWAYS; do
        log_msg "INFO" "Testando gateway: $gw"

        for ((r=1; r<=MAX_RETRIES; r++)); do
            if ping -c"$PING_COUNT" -W"$PING_TIMEOUT" "$gw" >/dev/null 2>&1; then
                log_msg "INFO" "Gateway $gw acessível."
                return 0
            fi

            log_msg "WARN" "Falha na tentativa $r/$MAX_RETRIES — Gateway $gw"
        done
    done

    log_msg "ERROR" "Nenhum gateway respondeu."
    send_to_zabbix 0 "Sem conexão com o gateway — Link caiu"
    exit 0
}

# -------------------------------------------------------------------
# Teste 2 — DNS (ping)
# -------------------------------------------------------------------
test_dns_servers() {
    log_msg "INFO" "Testando conectividade com servidores DNS..."

    for dns in "${DNS_SERVERS[@]}"; do
        log_msg "INFO" "Testando DNS: $dns"

        for ((r=1; r<=MAX_RETRIES; r++)); do
            if ping -c"$PING_COUNT" -W"$PING_TIMEOUT" "$dns" >/dev/null 2>&1; then
                log_msg "INFO" "DNS $dns acessível."
                return 0
            fi

            log_msg "WARN" "Falha $r/$MAX_RETRIES — DNS $dns"
        done
    done

    log_msg "ERROR" "Nenhum DNS respondeu."
    send_to_zabbix 1 "Gateway ok, mas sem acesso a DNS externos"
    exit 0
}

# -------------------------------------------------------------------
# Teste 3 — Resolução DNS
# -------------------------------------------------------------------
test_dns_resolution() {
    log_msg "INFO" "Testando resolução DNS..."

    for ((r=1; r<=MAX_RETRIES; r++)); do
        if nslookup google.com >/dev/null 2>&1; then
            log_msg "INFO" "Resolução DNS funcional."
            return 0
        fi

        log_msg "WARN" "Falha $r/$MAX_RETRIES — nslookup google.com"
    done

    log_msg "ERROR" "Resolução DNS falhou."
    send_to_zabbix 2 "DNS acessível, mas resolução falhando"
    exit 0
}

# -------------------------------------------------------------------
# Teste 4 — HTTP
# -------------------------------------------------------------------
test_http_access() {
    log_msg "INFO" "Testando acesso HTTP a sites reais..."

    for url in "${TEST_URLS[@]}"; do
        log_msg "INFO" "Testando URL: $url"

        for ((r=1; r<=MAX_RETRIES; r++)); do
            code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT" "$url")

            if [[ "$code" == "200" || "$code" == "301" || "$code" == "302" ]]; then
                log_msg "INFO" "HTTP OK — $url retornou código $code"
                return 0
            fi

            log_msg "WARN" "Falha $r/$MAX_RETRIES — HTTP $code em $url"
        done
    done

    log_msg "ERROR" "Nenhuma URL respondeu com sucesso."
    send_to_zabbix 2 "DNS responde, mas sem navegação HTTP"
    exit 0
}

# -------------------------------------------------------------------
# MAIN
# -------------------------------------------------------------------
main() {
    log_msg "INFO" "Iniciando verificação de conectividade..."

    check_tools
    test_gateway
    test_dns_servers
    test_dns_resolution
    test_http_access

    log_msg "INFO" "Todos os testes concluídos — Internet funcional."
    send_to_zabbix 3 "Internet 100% funcional"
}

main
