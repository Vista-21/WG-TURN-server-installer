#!/bin/bash

set -e

###############################################
# ЦВЕТА И ФУНКЦИИ ВЫВОДА
###############################################
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m"

ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERR ]${NC} $1"; }

###############################################
# ASCII БАННЕР
###############################################
clear
cat << "EOF"
 __        ___           ____                          _
 \ \      / (_)_ __     / ___|___  _ ____   _____ _ __| |
  \ \ /\ / /| | '_ \   | |   / _ \| '_ \ \ / / _ \ '__| |
   \ V  V / | | | | |  | |__| (_) | | | \ V /  __/ |  | |
    \_/\_/  |_|_| |_|   \____\___/|_| |_|\_/ \___|_|  |_|

     W I R E G U A R D  +  V K   T U R N   S E R V E R
     --------------------------------------------------
              Automated setup & management
EOF
echo
sleep 1

###############################################
# ОПРЕДЕЛЕНИЕ ОС
###############################################
info "Checking OS version..."
OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_CODENAME=$(grep -oP '(?<=VERSION_CODENAME=).+' /etc/os-release)
info "Detected: $OS_ID ($OS_CODENAME)"

###############################################
# ЗАПРОС ПОРТА С ПРОВЕРКОЙ ЗАНЯТОСТИ
###############################################
DEFAULT_PORT=37821

get_free_port() {
    local PORT
    while true; do
        if [ -t 0 ]; then
            read -p "Введите порт для WireGuard (по умолчанию $DEFAULT_PORT): " PORT
            PORT=${PORT:-$DEFAULT_PORT}
        else
            warn "stdin недоступен — порт выбран автоматически"
            PORT=$DEFAULT_PORT
        fi

        if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
            error "Порт должен быть числом"
            continue
        fi

        if ss -tuln | grep -q ":$PORT "; then
            PROC=$(ss -tulnp | grep ":$PORT " | awk -F '"' '{print $2}')
            error "Порт $PORT уже используется процессом: $PROC"
            continue
        fi

        echo "$PORT"
        return
    done
}

SERVER_PORT=$(get_free_port)
ok "WireGuard port set to: $SERVER_PORT"
echo

###############################################
# ПРОВЕРКА, УСТАНОВЛЕН ЛИ WIREGUARD
###############################################
if command -v wg >/dev/null 2>&1; then
    warn "WireGuard уже установлен. Используйте wg-clean для удаления."
    exit 0
fi

###############################################
# ИСПРАВЛЕНИЕ РЕПОЗИТОРИЕВ DEBIAN (БЕЗ BACKPORTS)
###############################################
if [[ "$OS_ID" == "debian" ]]; then
    info "Fixing Debian repositories..."

    # Удаляем все .list, чтобы не было дублей и backports
    rm -f /etc/apt/sources.list.d/*.list

    # Чистый sources.list
    cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian $OS_CODENAME main contrib non-free
deb http://deb.debian.org/debian $OS_CODENAME-updates main contrib non-free
deb http://security.debian.org/debian-security $OS_CODENAME-security main contrib non-free
EOF

    apt update
    ok "Debian repositories fixed"
fi

###############################################
# URL РЕПОЗИТОРИЯ (ВАЖНО!)
###############################################
REPO="https://raw.githubusercontent.com/Vista-21/WG-TURN-server-installer/main"

###############################################
# УСТАНОВКА WIREGUARD
###############################################
info "Installing WireGuard..."
apt install -y wireguard iptables curl wget qrencode whiptail
ok "WireGuard installed"

###############################################
# УСТАНОВКА NANO (если отсутствует)
###############################################
if ! command -v nano >/dev/null 2>&1; then
    info "Installing nano..."
    apt install -y nano
    ok "nano installed"
else
    ok "nano already installed"
fi

mkdir -p /etc/wireguard
mkdir -p ~/wg-clients

###############################################
# СКАЧИВАНИЕ СКРИПТОВ
###############################################
info "Downloading management scripts..."
curl -s -o /usr/local/bin/wg-add-client $REPO/wg-add-client.sh
curl -s -o /usr/local/bin/wg-del-client $REPO/wg-del-client.sh
curl -s -o /usr/local
