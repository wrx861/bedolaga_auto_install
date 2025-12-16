#!/bin/bash

# ===============================================
# 🛠️  УТИЛИТЫ И ФУНКЦИИ ВЫВОДА
# ===============================================

# Цвета для вывода
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# Функции вывода
print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     🤖 REMNAWAVE BEDOLAGA BOT - АВТОУСТАНОВЩИК 🤖           ║"
    echo "║                                                              ║"
    echo "║     Telegram бот для управления VPN подписками              ║"
    echo "║     через Remnawave API                                     ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Улучшенная функция подтверждения (y/n)
confirm() {
    local prompt="${1:-Продолжить?}"
    local default="${2:-n}"
    local response
    
    while true; do
        read -p "$prompt (y/n): " -n 1 response < /dev/tty
        echo
        case "$response" in
            [yY]) return 0 ;;
            [nN]) return 1 ;;
            *)
                echo -e "${YELLOW}   Пожалуйста, введите 'y' или 'n'${NC}"
                ;;
        esac
    done
}

# Генерация безопасного случайного токена (hex)
generate_token() {
    openssl rand -hex 32
}

# Генерация безопасного пароля (только буквы и цифры)
# ИСПРАВЛЕНИЕ БАГА: используем /dev/urandom напрямую для гарантированной длины
generate_safe_password() {
    local length="${1:-24}"
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

# Валидация домена
validate_domain() {
    local domain=$1
    
    # Проверка что домен содержит точку
    if [[ ! "$domain" =~ \. ]]; then
        return 1
    fi
    
    # Проверка что домен не содержит http:// или https://
    if [[ "$domain" =~ ^https?:// ]]; then
        return 1
    fi
    
    # Проверка формата домена (буквы, цифры, точки, дефисы)
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+[a-zA-Z0-9]$ ]]; then
        return 1
    fi
    
    return 0
}

# Проверка DNS записи домена
check_domain_dns() {
    local domain=$1
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
    local domain_ip=$(dig +short "$domain" 2>/dev/null | head -1)
    
    if [ -z "$server_ip" ]; then
        print_warning "Не удалось определить IP сервера"
        return 1
    fi
    
    if [ -z "$domain_ip" ]; then
        print_warning "DNS запись для $domain не найдена"
        return 1
    fi
    
    if [ "$server_ip" != "$domain_ip" ]; then
        print_warning "Домен $domain указывает на $domain_ip, а IP сервера: $server_ip"
        return 1
    fi
    
    print_success "DNS для $domain настроен правильно ($domain_ip)"
    return 0
}

# Проверка root прав
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Скрипт должен быть запущен от имени root!"
        echo -e "${YELLOW}Используйте: sudo bash install.sh${NC}"
        exit 1
    fi
}

# Определение дистрибутива
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Не удалось определить операционную систему"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            print_info "Обнаружена ОС: $PRETTY_NAME"
            ;;
        *)
            print_warning "Скрипт оптимизирован для Ubuntu/Debian"
            if ! confirm "Продолжить установку?"; then
                exit 1
            fi
            ;;
    esac
}
