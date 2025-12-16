#!/bin/bash

# ===============================================
# 🚀 REMNAWAVE BEDOLAGA BOT - АВТОУСТАНОВЩИК
# ===============================================
# Версия: 1.0.0
# Автор: Bedolaga Team
# GitHub: https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot
# ===============================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Переменные (будут установлены интерактивно)
INSTALL_DIR=""
REPO_URL="https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot.git"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
REMNAWAVE_PANEL_DIR=""
REMNAWAVE_DOCKER_NETWORK=""
PANEL_INSTALLED_LOCALLY="false"

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

# Выбор директории установки
select_install_dir() {
    print_step "Выбор директории установки"
    
    echo -e "${WHITE}Куда установить бота?${NC}"
    echo -e "  ${CYAN}1)${NC} /opt/remnawave-bedolaga-telegram-bot ${YELLOW}(рекомендуется если панель в /opt)${NC}"
    echo -e "  ${CYAN}2)${NC} /root/remnawave-bedolaga-telegram-bot"
    echo -e "  ${CYAN}3)${NC} Указать свой путь"
    echo
    
    while true; do
        read -p "Ваш выбор (1-3): " choice < /dev/tty
        case $choice in
            1)
                INSTALL_DIR="/opt/remnawave-bedolaga-telegram-bot"
                break
                ;;
            2)
                INSTALL_DIR="/root/remnawave-bedolaga-telegram-bot"
                break
                ;;
            3)
                read -p "Введите полный путь: " custom_path < /dev/tty
                if [ -n "$custom_path" ]; then
                    INSTALL_DIR="$custom_path"
                    break
                else
                    print_error "Путь не может быть пустым"
                fi
                ;;
            *)
                echo -e "${YELLOW}   Пожалуйста, введите 1, 2 или 3${NC}"
                ;;
        esac
    done
    
    print_success "Директория установки: $INSTALL_DIR"
}

# Проверка установленной панели Remnawave
check_remnawave_panel() {
    print_step "Проверка панели Remnawave"
    
    echo -e "${WHITE}Панель Remnawave установлена на этом сервере?${NC}"
    echo -e "${YELLOW}   (Если да, бот будет подключен к сети панели для связи по адресу http://remnawave:3000)${NC}"
    echo
    
    if confirm "Панель установлена на этом сервере?"; then
        PANEL_INSTALLED_LOCALLY="true"
        
        # Поиск директории панели
        echo
        echo -e "${WHITE}Где установлена панель?${NC}"
        echo -e "  ${CYAN}1)${NC} /opt/remnawave ${YELLOW}(стандартный путь)${NC}"
        echo -e "  ${CYAN}2)${NC} /root/remnawave"
        echo -e "  ${CYAN}3)${NC} Указать свой путь"
        echo
        
        while true; do
            read -p "Ваш выбор (1-3): " panel_choice < /dev/tty
            case $panel_choice in
                1)
                    REMNAWAVE_PANEL_DIR="/opt/remnawave"
                    break
                    ;;
                2)
                    REMNAWAVE_PANEL_DIR="/root/remnawave"
                    break
                    ;;
                3)
                    read -p "Введите путь к директории панели: " custom_panel < /dev/tty
                    if [ -n "$custom_panel" ]; then
                        REMNAWAVE_PANEL_DIR="$custom_panel"
                        break
                    else
                        print_error "Путь не может быть пустым"
                    fi
                    ;;
                *)
                    echo -e "${YELLOW}   Пожалуйста, введите 1, 2 или 3${NC}"
                    ;;
            esac
        done
        
        # Проверка существования директории
        if [ ! -d "$REMNAWAVE_PANEL_DIR" ]; then
            print_warning "Директория $REMNAWAVE_PANEL_DIR не найдена"
            if ! confirm "Продолжить всё равно?"; then
                exit 1
            fi
        else
            print_success "Панель найдена: $REMNAWAVE_PANEL_DIR"
        fi
        
        # Определение Docker сети панели
        detect_panel_network
    else
        PANEL_INSTALLED_LOCALLY="false"
        print_info "Бот будет установлен отдельно. Укажите внешний URL панели при настройке."
    fi
}

# Определение Docker сети панели
detect_panel_network() {
    print_info "Поиск Docker сети панели Remnawave..."
    
    # Способ 1: Найти сеть по запущенному контейнеру remnawave
    local container_network=$(docker inspect remnawave --format '{{range $net, $config := .NetworkSettings.Networks}}{{$net}}{{"\n"}}{{end}}' 2>/dev/null | grep -v "^$" | head -1)
    if [ -n "$container_network" ] && [ "$container_network" != "host" ] && [ "$container_network" != "none" ]; then
        REMNAWAVE_DOCKER_NETWORK="$container_network"
        print_success "Найдена Docker сеть контейнера remnawave: $REMNAWAVE_DOCKER_NETWORK"
        return
    fi
    
    # Способ 2: Поиск сети по известным именам
    local possible_networks=("remnawave-network" "remnawave_default" "remnawave_network" "remnawave" "remnawave-panel_default")
    
    for net in "${possible_networks[@]}"; do
        if docker network inspect "$net" &>/dev/null; then
            REMNAWAVE_DOCKER_NETWORK="$net"
            print_success "Найдена Docker сеть: $REMNAWAVE_DOCKER_NETWORK"
            return
        fi
    done
    
    # Способ 3: Поиск сети содержащей "remnawave" в имени (исключая сети бота)
    local found_network=$(docker network ls --format '{{.Name}}' | grep -i "remnawave" | grep -v "bedolaga" | grep -v "bot" | head -1)
    if [ -n "$found_network" ]; then
        REMNAWAVE_DOCKER_NETWORK="$found_network"
        print_success "Найдена Docker сеть: $REMNAWAVE_DOCKER_NETWORK"
        return
    fi
    
    # Способ 4: Поиск сети в docker-compose панели
    if [ -f "$REMNAWAVE_PANEL_DIR/docker-compose.yml" ]; then
        local net_from_compose=$(grep -A5 "networks:" "$REMNAWAVE_PANEL_DIR/docker-compose.yml" 2>/dev/null | grep "name:" | head -1 | sed 's/.*name:\s*//' | tr -d ' "'"'"'')
        if [ -n "$net_from_compose" ] && docker network inspect "$net_from_compose" &>/dev/null; then
            REMNAWAVE_DOCKER_NETWORK="$net_from_compose"
            print_success "Найдена Docker сеть из compose: $REMNAWAVE_DOCKER_NETWORK"
            return
        fi
    fi
    
    # Не удалось найти автоматически - спросить пользователя
    print_warning "Не удалось автоматически определить Docker сеть панели"
    echo
    echo -e "${WHITE}Доступные Docker сети:${NC}"
    docker network ls --format "  - {{.Name}}" | grep -v "bridge\|host\|none"
    echo
    read -p "Введите имя сети панели (или Enter для пропуска): " manual_network < /dev/tty
    
    if [ -n "$manual_network" ]; then
        if docker network inspect "$manual_network" &>/dev/null; then
            REMNAWAVE_DOCKER_NETWORK="$manual_network"
            print_success "Используем сеть: $REMNAWAVE_DOCKER_NETWORK"
        else
            print_error "Сеть $manual_network не найдена"
            REMNAWAVE_DOCKER_NETWORK=""
        fi
    else
        print_warning "Сеть не выбрана. Бот может не иметь связи с панелью!"
        print_info "Вы можете настроить это позже вручную"
    fi
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

# Обновление системы
update_system() {
    print_step "Обновление системы"
    apt-get update -y
    apt-get upgrade -y
    print_success "Система обновлена"
}

# Установка базовых пакетов
install_base_packages() {
    print_step "Проверка и установка базовых пакетов"
    
    # Список необходимых пакетов
    local packages=(curl wget git nano htop ufw certbot python3-certbot-nginx make openssl ca-certificates gnupg lsb-release dnsutils)
    local missing_packages=()
    
    # Проверяем какие пакеты отсутствуют
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" &>/dev/null; then
            missing_packages+=("$pkg")
        fi
    done
    
    # Если все пакеты установлены - пропускаем
    if [ ${#missing_packages[@]} -eq 0 ]; then
        print_success "Все базовые пакеты уже установлены"
        return 0
    fi
    
    # Устанавливаем только отсутствующие пакеты
    print_info "Устанавливаем недостающие пакеты: ${missing_packages[*]}"
    apt-get install -y "${missing_packages[@]}"
    print_success "Базовые пакеты установлены"
}

# Установка Docker
install_docker() {
    print_step "Установка Docker"
    
    if command -v docker &> /dev/null; then
        print_info "Docker уже установлен: $(docker --version)"
    else
        print_info "Установка Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
        print_success "Docker установлен: $(docker --version)"
    fi
    
    # Проверка Docker Compose
    if docker compose version &> /dev/null; then
        print_info "Docker Compose: $(docker compose version)"
    else
        print_error "Docker Compose не найден"
        exit 1
    fi
}

# Установка Nginx
install_nginx() {
    print_step "Установка Nginx"
    
    if command -v nginx &> /dev/null; then
        print_info "Nginx уже установлен: $(nginx -v 2>&1)"
    else
        apt-get install -y nginx
        systemctl enable nginx
        systemctl start nginx
        print_success "Nginx установлен"
    fi
}

# Клонирование репозитория
clone_repository() {
    print_step "Клонирование репозитория"
    
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Директория $INSTALL_DIR уже существует"
        if confirm "Удалить и клонировать заново?"; then
            rm -rf "$INSTALL_DIR"
        else
            print_info "Используем существующую директорию"
            cd "$INSTALL_DIR"
            git pull origin main || true
            return
        fi
    fi
    
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    print_success "Репозиторий клонирован в $INSTALL_DIR"
}

# Создание необходимых директорий
create_directories() {
    print_step "Создание директорий"
    
    cd "$INSTALL_DIR"
    mkdir -p ./logs ./data ./data/backups ./data/referral_qr ./locales
    chmod -R 755 ./logs ./data ./locales
    chown -R 1000:1000 ./logs ./data ./locales 2>/dev/null || true
    
    print_success "Директории созданы"
}

# Генерация случайных токенов
generate_token() {
    openssl rand -hex 32
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

# Ввод и валидация домена
input_domain() {
    local prompt=$1
    local var_name=$2
    local result=""
    
    while true; do
        read -p "$prompt" result < /dev/tty
        
        # Пустое значение - пропуск
        if [ -z "$result" ]; then
            eval "$var_name=''"
            return 0
        fi
        
        # Убираем протокол если есть
        result=$(echo "$result" | sed 's|^https\?://||' | sed 's|/$||')
        
        # Валидация формата
        if ! validate_domain "$result"; then
            print_error "Неверный формат домена: $result"
            echo -e "${YELLOW}   Домен должен быть вида: bot.example.com${NC}"
            echo -e "${YELLOW}   Введите домен заново или оставьте пустым для пропуска${NC}"
            continue
        fi
        
        # Проверка DNS
        echo -e "${BLUE}   Проверка DNS записи...${NC}"
        if ! check_domain_dns "$result"; then
            echo
            echo -e "${RED}   ⚠️  DNS запись не найдена!${NC}"
            echo -e "${YELLOW}   Проверьте DNS записи у вашего регистратора домена${NC}"
            echo -e "${YELLOW}   или нажмите Enter чтобы пропустить и настроить DNS позже${NC}"
            echo
            echo -e "${YELLOW}   Варианты:${NC}"
            echo -e "${YELLOW}   1) Ввести другой домен${NC}"
            echo -e "${YELLOW}   2) Продолжить с этим доменом (DNS можно настроить позже)${NC}"
            echo -e "${YELLOW}   3) Пропустить - Enter (режим polling без webhook)${NC}"
            echo
            read -p "   Выберите (1/2/3 или Enter для пропуска): " choice < /dev/tty
            
            case $choice in
                1) continue ;;
                2) 
                    eval "$var_name='$result'"
                    return 0
                    ;;
                3|"")
                    eval "$var_name=''"
                    print_info "Пропущено. Вы сможете настроить DNS и webhook позже."
                    return 0
                    ;;
                *)
                    continue
                    ;;
            esac
        fi
        
        eval "$var_name='$result'"
        return 0
    done
}

# Интерактивная настройка
interactive_setup() {
    print_step "Интерактивная настройка"
    
    echo -e "${WHITE}Пожалуйста, введите необходимые данные:${NC}\n"
    
    # BOT_TOKEN
    echo -e "${CYAN}1. Telegram Bot Token${NC}"
    echo -e "${YELLOW}   Получить у @BotFather${NC}"
    read -p "   BOT_TOKEN: " BOT_TOKEN < /dev/tty
    while [ -z "$BOT_TOKEN" ]; do
        print_error "BOT_TOKEN обязателен!"
        read -p "   BOT_TOKEN: " BOT_TOKEN < /dev/tty
    done
    
    # ADMIN_IDS
    echo -e "\n${CYAN}2. Admin Telegram IDs${NC}"
    echo -e "${YELLOW}   Ваш Telegram ID (можно узнать у @userinfobot)${NC}"
    echo -e "${YELLOW}   Для нескольких админов разделите запятой: 123456789,987654321${NC}"
    read -p "   ADMIN_IDS: " ADMIN_IDS < /dev/tty
    while [ -z "$ADMIN_IDS" ]; do
        print_error "ADMIN_IDS обязателен!"
        read -p "   ADMIN_IDS: " ADMIN_IDS < /dev/tty
    done
    
    # REMNAWAVE_API_URL
    echo -e "\n${CYAN}3. Remnawave Panel URL${NC}"
    if [ "$PANEL_INSTALLED_LOCALLY" = "true" ] && [ -n "$REMNAWAVE_DOCKER_NETWORK" ]; then
        echo -e "${GREEN}   Панель установлена локально - используем внутренний адрес${NC}"
        echo -e "${YELLOW}   Рекомендуется: http://remnawave:3000${NC}"
        echo -e "${YELLOW}   Или укажите внешний URL: https://panel.yourdomain.com${NC}"
        echo -e "${WHITE}   Нажмите Enter чтобы использовать рекомендуемый адрес${NC}"
        read -p "   REMNAWAVE_API_URL [http://remnawave:3000]: " REMNAWAVE_API_URL < /dev/tty
        if [ -z "$REMNAWAVE_API_URL" ]; then
            REMNAWAVE_API_URL="http://remnawave:3000"
            print_info "Используется: $REMNAWAVE_API_URL"
        fi
    else
        echo -e "${YELLOW}   Пример: https://panel.yourdomain.com${NC}"
        read -p "   REMNAWAVE_API_URL: " REMNAWAVE_API_URL < /dev/tty
        while [ -z "$REMNAWAVE_API_URL" ]; do
            print_error "REMNAWAVE_API_URL обязателен!"
            read -p "   REMNAWAVE_API_URL: " REMNAWAVE_API_URL < /dev/tty
        done
    fi
    
    # REMNAWAVE_API_KEY
    echo -e "\n${CYAN}4. Remnawave API Key${NC}"
    echo -e "${YELLOW}   Получить в панели Remnawave${NC}"
    read -p "   REMNAWAVE_API_KEY: " REMNAWAVE_API_KEY < /dev/tty
    while [ -z "$REMNAWAVE_API_KEY" ]; do
        print_error "REMNAWAVE_API_KEY обязателен!"
        read -p "   REMNAWAVE_API_KEY: " REMNAWAVE_API_KEY < /dev/tty
    done
    
    # Домен для webhook (опционально)
    echo -e "\n${CYAN}5. Домен для webhook (опционально)${NC}"
    echo -e "${YELLOW}   Пример: bot.yourdomain.com${NC}"
    echo -e "${YELLOW}   Оставьте пустым для режима polling${NC}"
    input_domain "   WEBHOOK_DOMAIN: " WEBHOOK_DOMAIN
    
    # Домен для miniapp (опционально)
    echo -e "\n${CYAN}6. Домен для Mini App (опционально)${NC}"
    echo -e "${YELLOW}   Пример: miniapp.yourdomain.com${NC}"
    input_domain "   MINIAPP_DOMAIN: " MINIAPP_DOMAIN
    
    # Настройки уведомлений
    echo -e "\n${CYAN}7. Chat ID для уведомлений (опционально)${NC}"
    echo -e "${YELLOW}   ID группы/канала для админ уведомлений${NC}"
    echo -e "${YELLOW}   Формат: -1001234567890${NC}"
    read -p "   ADMIN_NOTIFICATIONS_CHAT_ID: " ADMIN_NOTIFICATIONS_CHAT_ID < /dev/tty
    
    # PostgreSQL пароль
    echo -e "\n${CYAN}8. Пароль для PostgreSQL${NC}"
    echo -e "${YELLOW}   Оставьте пустым для автогенерации${NC}"
    read -s -p "   POSTGRES_PASSWORD: " POSTGRES_PASSWORD < /dev/tty
    echo
    if [ -z "$POSTGRES_PASSWORD" ]; then
        POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
        print_info "Сгенерирован пароль PostgreSQL"
    fi
    
    # Генерация токенов
    WEBHOOK_SECRET_TOKEN=$(generate_token)
    WEB_API_DEFAULT_TOKEN=$(generate_token)
    
    # Определение режима работы
    if [ -n "$WEBHOOK_DOMAIN" ]; then
        BOT_RUN_MODE="webhook"
        WEBHOOK_URL="https://$WEBHOOK_DOMAIN"
        WEB_API_ENABLED="true"
    else
        BOT_RUN_MODE="polling"
        WEBHOOK_URL=""
        WEB_API_ENABLED="false"
    fi
    
    print_success "Данные собраны"
}

# Создание .env файла
create_env_file() {
    print_step "Создание файла конфигурации .env"
    
    cd "$INSTALL_DIR"
    
    # Определяем ADMIN_NOTIFICATIONS_ENABLED
    if [ -n "$ADMIN_NOTIFICATIONS_CHAT_ID" ]; then
        ADMIN_NOTIFICATIONS_ENABLED="true"
    else
        ADMIN_NOTIFICATIONS_ENABLED="false"
    fi
    
    cat > .env << EOF
# ===============================================
# 🤖 REMNAWAVE BEDOLAGA BOT CONFIGURATION
# ===============================================
# Сгенерировано автоустановщиком: $(date)
# ===============================================

# ===== TELEGRAM BOT =====
BOT_TOKEN=${BOT_TOKEN}
ADMIN_IDS=${ADMIN_IDS}
SUPPORT_USERNAME=@support

# ===== УВЕДОМЛЕНИЯ =====
ADMIN_NOTIFICATIONS_ENABLED=${ADMIN_NOTIFICATIONS_ENABLED}
EOF

    # Добавляем ADMIN_NOTIFICATIONS_CHAT_ID только если он не пустой
    if [ -n "$ADMIN_NOTIFICATIONS_CHAT_ID" ]; then
        echo "ADMIN_NOTIFICATIONS_CHAT_ID=${ADMIN_NOTIFICATIONS_CHAT_ID}" >> .env
    fi
    
    # Продолжаем .env файл
    cat >> .env << EOF

# ===== DATABASE =====
DATABASE_MODE=auto
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=remnawave_bot
POSTGRES_USER=remnawave_user
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# ===== REDIS =====
REDIS_URL=redis://redis:6379/0

# ===== REMNAWAVE API =====
REMNAWAVE_API_URL=${REMNAWAVE_API_URL}
REMNAWAVE_API_KEY=${REMNAWAVE_API_KEY}
REMNAWAVE_AUTH_TYPE=api_key

# ===== ПОДПИСКИ =====
TRIAL_DURATION_DAYS=3
TRIAL_TRAFFIC_LIMIT_GB=10
TRIAL_DEVICE_LIMIT=1
DEFAULT_DEVICE_LIMIT=3
MAX_DEVICES_LIMIT=15

# ===== ПЕРИОДЫ И ЦЕНЫ =====
AVAILABLE_SUBSCRIPTION_PERIODS=30,90,180
AVAILABLE_RENEWAL_PERIODS=30,90,180
PRICE_14_DAYS=7000
PRICE_30_DAYS=10000
PRICE_60_DAYS=25900
PRICE_90_DAYS=36900
PRICE_180_DAYS=69900
PRICE_360_DAYS=109900

# ===== ТРАФИК =====
TRAFFIC_SELECTION_MODE=selectable
TRAFFIC_PACKAGES_CONFIG="5:2000:false,10:3500:false,25:7000:false,50:11000:true,100:15000:true,250:17000:false,500:19000:false,1000:19500:true,0:20000:true"

# ===== РЕФЕРАЛЬНАЯ СИСТЕМА =====
REFERRAL_PROGRAM_ENABLED=true
REFERRAL_MINIMUM_TOPUP_KOPEKS=10000
REFERRAL_FIRST_TOPUP_BONUS_KOPEKS=10000
REFERRAL_INVITER_BONUS_KOPEKS=10000
REFERRAL_COMMISSION_PERCENT=25

# ===== TELEGRAM STARS =====
TELEGRAM_STARS_ENABLED=true
TELEGRAM_STARS_RATE_RUB=1.79

# ===== ИНТЕРФЕЙС =====
ENABLE_LOGO_MODE=true
LOGO_FILE=vpn_logo.png
MAIN_MENU_MODE=default
DEFAULT_LANGUAGE=ru
AVAILABLE_LANGUAGES=ru,en
LANGUAGE_SELECTION_ENABLED=true

# ===== WEBHOOK & WEB API =====
BOT_RUN_MODE=${BOT_RUN_MODE}
EOF

    # Добавляем WEBHOOK_URL только если не пустой
    if [ -n "$WEBHOOK_URL" ]; then
        echo "WEBHOOK_URL=${WEBHOOK_URL}" >> .env
    fi
    
    cat >> .env << EOF
WEBHOOK_PATH=/webhook
WEBHOOK_SECRET_TOKEN=${WEBHOOK_SECRET_TOKEN}
WEBHOOK_DROP_PENDING_UPDATES=true

WEB_API_ENABLED=${WEB_API_ENABLED}
WEB_API_HOST=0.0.0.0
WEB_API_PORT=8080
WEB_API_ALLOWED_ORIGINS=*
WEB_API_DOCS_ENABLED=false
WEB_API_DEFAULT_TOKEN=${WEB_API_DEFAULT_TOKEN}

# ===== БЭКАПЫ =====
BACKUP_AUTO_ENABLED=true
BACKUP_INTERVAL_HOURS=24
BACKUP_TIME=03:00
BACKUP_MAX_KEEP=7
BACKUP_COMPRESSION=true
BACKUP_LOCATION=/app/data/backups

# ===== МОНИТОРИНГ =====
MONITORING_INTERVAL=60
MAINTENANCE_MODE=false
MAINTENANCE_AUTO_ENABLE=true
MAINTENANCE_MONITORING_ENABLED=true

# ===== ПРОВЕРКА ОБНОВЛЕНИЙ =====
VERSION_CHECK_ENABLED=true
VERSION_CHECK_REPO=BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot
VERSION_CHECK_INTERVAL_HOURS=1

# ===== ЛОГИРОВАНИЕ =====
LOG_LEVEL=INFO
LOG_FILE=logs/bot.log
TZ=Europe/Moscow
EOF

    chmod 600 .env
    print_success "Файл .env создан"
}

# Проверка Mini App - файлы уже есть в папке miniapp репозитория бота
# Бот сам отдаёт статику miniapp на порту 8080
setup_miniapp_files() {
    if [ -z "$MINIAPP_DOMAIN" ]; then
        return 0
    fi
    
    print_step "Проверка Mini App"
    
    cd "$INSTALL_DIR"
    
    # Проверяем наличие папки miniapp в репозитории бота
    if [ -d "$INSTALL_DIR/miniapp" ]; then
        print_success "Mini App найден в $INSTALL_DIR/miniapp"
        print_info "Бот будет отдавать статику Mini App на порту 8080"
    else
        print_warning "Папка miniapp не найдена в репозитории!"
        echo -e "${YELLOW}Возможно репозиторий устарел. Обновите его:${NC}"
        echo -e "${CYAN}  cd $INSTALL_DIR && git pull${NC}"
    fi
}

# Создание стандартного docker-compose.yml для отдельной установки (без сети панели)
create_standalone_compose() {
    print_info "Создание docker-compose.yml для отдельной установки..."
    
    cat > docker-compose.yml << 'STANDALONEEOF'
services:
  postgres:
    image: postgres:15-alpine
    container_name: remnawave_bot_db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-remnawave_bot}
      POSTGRES_USER: ${POSTGRES_USER:-remnawave_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-secure_password_123}
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - bot_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-remnawave_user} -d ${POSTGRES_DB:-remnawave_bot}"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 30s

  redis:
    image: redis:7-alpine
    container_name: remnawave_bot_redis
    restart: unless-stopped
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    networks:
      - bot_network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  bot:
    build: .
    container_name: remnawave_bot
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    env_file:
      - .env
    environment:
      DOCKER_ENV: "true"
      DATABASE_MODE: "auto"
      POSTGRES_HOST: "postgres"
      POSTGRES_PORT: "5432"
      POSTGRES_DB: "${POSTGRES_DB:-remnawave_bot}"
      POSTGRES_USER: "${POSTGRES_USER:-remnawave_user}"
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-secure_password_123}"
      REDIS_URL: "redis://redis:6379/0"
      TZ: "Europe/Moscow"
      LOCALES_PATH: "${LOCALES_PATH:-/app/locales}"
    volumes:
      - ./logs:/app/logs:rw
      - ./data:/app/data:rw
      - ./locales:/app/locales:rw
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
      - ./vpn_logo.png:/app/vpn_logo.png:ro
    ports:
      - "${WEB_API_PORT:-8080}:8080"
    networks:
      - bot_network
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:8080/health || exit 1"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 30s

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local

networks:
  bot_network:
    name: remnawave_bot_network
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1
STANDALONEEOF
    print_success "Создан docker-compose.yml для отдельной установки"
}

# Настройка Nginx
setup_nginx() {
    if [ -z "$WEBHOOK_DOMAIN" ] && [ -z "$MINIAPP_DOMAIN" ]; then
        print_info "Домены не указаны, пропускаем настройку Nginx"
        return
    fi
    
    print_step "Настройка Nginx"
    
    # Проверяем используется ли nginx панели в режиме host
    PANEL_NGINX_HOST_MODE="false"
    PANEL_NGINX_CONF=""
    
    if [ "$PANEL_INSTALLED_LOCALLY" = "true" ] && [ -n "$REMNAWAVE_PANEL_DIR" ]; then
        # Проверяем контейнер remnawave-nginx в режиме host
        local nginx_network=$(docker inspect remnawave-nginx --format '{{.HostConfig.NetworkMode}}' 2>/dev/null)
        if [ "$nginx_network" = "host" ]; then
            PANEL_NGINX_HOST_MODE="true"
            PANEL_NGINX_CONF="$REMNAWAVE_PANEL_DIR/nginx.conf"
            print_info "Обнаружен nginx панели в режиме host"
            print_info "Конфигурация будет добавлена в: $PANEL_NGINX_CONF"
        fi
    fi
    
    if [ "$PANEL_NGINX_HOST_MODE" = "true" ] && [ -f "$PANEL_NGINX_CONF" ]; then
        # Добавляем конфиг в nginx панели
        setup_nginx_panel_mode
    else
        # Используем системный nginx
        setup_nginx_system_mode
    fi
}

# Добавление SSL сертификатов бота в docker-compose панели
add_ssl_to_panel_compose() {
    local panel_compose="$REMNAWAVE_PANEL_DIR/docker-compose.yml"
    
    if [ ! -f "$panel_compose" ]; then
        print_warning "docker-compose.yml панели не найден: $panel_compose"
        return 1
    fi
    
    print_info "Добавление SSL сертификатов бота в docker-compose панели..."
    print_info "Файл: $panel_compose"
    
    # Создаём бэкап
    cp "$panel_compose" "$panel_compose.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Проверяем, не смонтирована ли уже вся папка /etc/letsencrypt
    if grep -q "/etc/letsencrypt:/etc/letsencrypt" "$panel_compose"; then
        print_info "Папка /etc/letsencrypt уже смонтирована"
        return 0
    fi
    
    # Ищем последнюю строку с .pem:ro в секции remnawave-nginx
    local last_pem_line=$(grep -n "\.pem:ro" "$panel_compose" | tail -1 | cut -d: -f1)
    
    if [ -z "$last_pem_line" ]; then
        print_warning "Не найдены существующие сертификаты в docker-compose.yml"
        print_warning "Попробуем найти секцию volumes в remnawave-nginx..."
        
        # Альтернативный способ - найти network_mode: host и вставить перед ним
        local nginx_start=$(grep -n "remnawave-nginx:" "$panel_compose" | head -1 | cut -d: -f1)
        local network_line=$(tail -n +${nginx_start:-1} "$panel_compose" | grep -n "network_mode:" | head -1 | cut -d: -f1)
        
        if [ -n "$nginx_start" ] && [ -n "$network_line" ]; then
            last_pem_line=$((nginx_start + network_line - 2))
            print_info "Найдена позиция для вставки: строка $last_pem_line"
        else
            print_error "Не удалось найти место для вставки в docker-compose.yml"
            return 1
        fi
    fi
    
    print_info "Вставка после строки $last_pem_line"
    
    # Добавляем монтирование всей папки letsencrypt (для работы симлинков)
    local new_line="      - /etc/letsencrypt:/etc/letsencrypt:ro"
    
    # Вставляем после найденной строки
    head -n "$last_pem_line" "$panel_compose" > "$panel_compose.tmp"
    echo "$new_line" >> "$panel_compose.tmp"
    tail -n +$((last_pem_line + 1)) "$panel_compose" >> "$panel_compose.tmp"
    
    mv "$panel_compose.tmp" "$panel_compose"
    
    # Проверяем что добавилось
    if grep -q "/etc/letsencrypt:/etc/letsencrypt" "$panel_compose"; then
        print_success "Монтирование /etc/letsencrypt добавлено в docker-compose панели"
        # Показываем что добавилось
        print_info "Проверка:"
        grep -n "letsencrypt" "$panel_compose" | tail -3
    else
        print_error "Не удалось добавить монтирование сертификатов"
        return 1
    fi
    
    return 0
}

# Добавление монтирования папки miniapp бота в docker-compose панели
add_miniapp_to_panel_compose() {
    if [ -z "$MINIAPP_DOMAIN" ]; then
        return 0
    fi
    
    local panel_compose="$REMNAWAVE_PANEL_DIR/docker-compose.yml"
    
    if [ ! -f "$panel_compose" ]; then
        print_warning "docker-compose.yml панели не найден: $panel_compose"
        return 1
    fi
    
    # Проверяем, не смонтирована ли уже папка miniapp
    if grep -q "remnawave-miniapp" "$panel_compose"; then
        print_info "Папка miniapp уже смонтирована в nginx панели"
        return 0
    fi
    
    print_info "Добавление монтирования miniapp в docker-compose панели..."
    
    # Ищем последнюю строку с .pem:ro или letsencrypt в секции remnawave-nginx
    local last_volume_line=$(grep -n "letsencrypt\|\.pem:ro" "$panel_compose" | tail -1 | cut -d: -f1)
    
    if [ -z "$last_volume_line" ]; then
        # Пробуем найти секцию volumes в remnawave-nginx
        local nginx_start=$(grep -n "remnawave-nginx:" "$panel_compose" | head -1 | cut -d: -f1)
        if [ -n "$nginx_start" ]; then
            last_volume_line=$(tail -n +${nginx_start} "$panel_compose" | grep -n "volumes:" | head -1 | cut -d: -f1)
            if [ -n "$last_volume_line" ]; then
                last_volume_line=$((nginx_start + last_volume_line))
            fi
        fi
    fi
    
    if [ -z "$last_volume_line" ]; then
        print_warning "Не удалось найти место для монтирования miniapp"
        return 1
    fi
    
    # Добавляем монтирование папки miniapp
    local miniapp_mount="      - ${INSTALL_DIR}/miniapp:/var/www/remnawave-miniapp:ro"
    
    # Вставляем после найденной строки
    head -n "$last_volume_line" "$panel_compose" > "$panel_compose.tmp"
    echo "$miniapp_mount" >> "$panel_compose.tmp"
    tail -n +$((last_volume_line + 1)) "$panel_compose" >> "$panel_compose.tmp"
    
    mv "$panel_compose.tmp" "$panel_compose"
    
    if grep -q "remnawave-miniapp" "$panel_compose"; then
        print_success "Монтирование miniapp добавлено в docker-compose панели"
        print_info "Путь: ${INSTALL_DIR}/miniapp -> /var/www/remnawave-miniapp"
    else
        print_error "Не удалось добавить монтирование miniapp"
        return 1
    fi
    
    return 0
}

# Настройка через nginx панели (host mode)
setup_nginx_panel_mode() {
    print_info "Настройка через nginx панели Remnawave..."
    
    # Создаём backup
    cp "$PANEL_NGINX_CONF" "$PANEL_NGINX_CONF.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Проверяем есть ли уже конфиг бота
    if grep -q "Bedolaga Bot" "$PANEL_NGINX_CONF" 2>/dev/null; then
        print_warning "Конфигурация бота уже существует в nginx панели"
        if confirm "Перезаписать конфигурацию бота?"; then
            # Удаляем старый конфиг бота (между маркерами)
            sed -i '/# === BEGIN Bedolaga Bot ===/,/# === END Bedolaga Bot ===/d' "$PANEL_NGINX_CONF"
        else
            return
        fi
    fi
    
    # Формируем блок конфигурации для бота
    local bot_nginx_block=""
    
    # Webhook домен
    if [ -n "$WEBHOOK_DOMAIN" ]; then
        bot_nginx_block+="
# === BEGIN Bedolaga Bot ===
# Bedolaga Bot Webhook - $WEBHOOK_DOMAIN
server {
    server_name ${WEBHOOK_DOMAIN};
    listen 443 ssl;
    http2 on;

    ssl_certificate \"/etc/letsencrypt/live/${WEBHOOK_DOMAIN}/fullchain.pem\";
    ssl_certificate_key \"/etc/letsencrypt/live/${WEBHOOK_DOMAIN}/privkey.pem\";

    client_max_body_size 32m;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
        proxy_buffering off;
    }
}
"
    fi
    
    # Miniapp домен
    if [ -n "$MINIAPP_DOMAIN" ]; then
        bot_nginx_block+="
# Bedolaga Bot Mini App - $MINIAPP_DOMAIN
server {
    server_name ${MINIAPP_DOMAIN};
    listen 443 ssl;
    http2 on;

    ssl_certificate \"/etc/letsencrypt/live/${MINIAPP_DOMAIN}/fullchain.pem\";
    ssl_certificate_key \"/etc/letsencrypt/live/${MINIAPP_DOMAIN}/privkey.pem\";

    client_max_body_size 32m;

    # API эндпоинты /miniapp/* проксируем на бота
    location /miniapp/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
    }

    # app-config.json с CORS проксируем на бота
    location = /app-config.json {
        add_header Access-Control-Allow-Origin \"*\";
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Статические файлы Mini App (из примонтированной папки)
    location / {
        root /var/www/remnawave-miniapp;
        try_files \$uri \$uri/ /index.html;
        expires 1h;
        add_header Cache-Control \"public, immutable\";
    }
}
"
    fi
    
    bot_nginx_block+="# === END Bedolaga Bot ===
"
    
    # Вставляем конфиг ПЕРЕД default_server (который отклоняет неизвестные домены)
    # Ищем строку с "default_server" и вставляем перед ней
    if grep -q "default_server" "$PANEL_NGINX_CONF"; then
        # Находим номер строки с default_server
        local line_num=$(grep -n "listen 443 ssl default_server" "$PANEL_NGINX_CONF" | head -1 | cut -d: -f1)
        if [ -n "$line_num" ]; then
            # Находим начало этого server блока (ищем "server {" выше)
            local server_start=$((line_num - 1))
            while [ $server_start -gt 0 ]; do
                if sed -n "${server_start}p" "$PANEL_NGINX_CONF" | grep -q "^server {"; then
                    break
                fi
                server_start=$((server_start - 1))
            done
            
            # Вставляем перед этим блоком
            if [ $server_start -gt 0 ]; then
                # Создаём временный файл с новым содержимым
                head -n $((server_start - 1)) "$PANEL_NGINX_CONF" > "$PANEL_NGINX_CONF.tmp"
                echo "$bot_nginx_block" >> "$PANEL_NGINX_CONF.tmp"
                tail -n +$server_start "$PANEL_NGINX_CONF" >> "$PANEL_NGINX_CONF.tmp"
                mv "$PANEL_NGINX_CONF.tmp" "$PANEL_NGINX_CONF"
            else
                # Если не нашли, просто добавляем в конец перед последней }
                echo "$bot_nginx_block" >> "$PANEL_NGINX_CONF"
            fi
        else
            echo "$bot_nginx_block" >> "$PANEL_NGINX_CONF"
        fi
    else
        # Нет default_server, просто добавляем в конец
        echo "$bot_nginx_block" >> "$PANEL_NGINX_CONF"
    fi
    
    print_success "Конфигурация бота добавлена в nginx панели"
    
    # SSL сертификаты добавляются позже, после их создания (в main)
    
    # Удаляем конфликтующие системные конфиги если есть
    if [ -f "$NGINX_ENABLED/bedolaga-webhook" ]; then
        rm -f "$NGINX_ENABLED/bedolaga-webhook"
        rm -f "$NGINX_AVAILABLE/bedolaga-webhook"
        print_info "Удалён конфликтующий системный конфиг webhook"
    fi
    if [ -f "$NGINX_ENABLED/bedolaga-miniapp" ]; then
        rm -f "$NGINX_ENABLED/bedolaga-miniapp"
        rm -f "$NGINX_AVAILABLE/bedolaga-miniapp"
        print_info "Удалён конфликтующий системный конфиг miniapp"
    fi
    
    # Добавляем монтирование папки miniapp в docker-compose панели (если нужен miniapp)
    if [ -n "$MINIAPP_DOMAIN" ]; then
        add_miniapp_to_panel_compose
    fi
    
    # Перезапускаем nginx панели (с пересозданием для подхвата новых volumes)
    print_info "Перезапуск nginx панели..."
    cd "$REMNAWAVE_PANEL_DIR"
    # Используем up -d для пересоздания контейнера с новыми volumes
    docker compose up -d remnawave-nginx 2>/dev/null || docker compose restart remnawave-nginx 2>/dev/null || docker restart remnawave-nginx 2>/dev/null
    
    # Перезагружаем системный nginx если он работает
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx 2>/dev/null || true
    fi
    
    print_success "Nginx настроен через контейнер панели"
}

# Настройка через системный nginx
setup_nginx_system_mode() {
    print_info "Настройка через системный nginx..."
    
    # Конфигурация для webhook домена
    if [ -n "$WEBHOOK_DOMAIN" ]; then
        print_info "Создание конфигурации для $WEBHOOK_DOMAIN"
        
        cat > "$NGINX_AVAILABLE/bedolaga-webhook" << EOF
# Remnawave Bedolaga Bot - Webhook & API
server {
    listen 80;
    server_name ${WEBHOOK_DOMAIN};
    
    client_max_body_size 32m;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Webhook пути для платежных систем
    location = /yookassa-webhook {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location = /cryptobot-webhook {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location = /tribute-webhook {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location = /heleket-webhook {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location = /mulenpay-webhook {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location = /pal24-webhook {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location = /platega-webhook {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location = /wata-webhook {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # app-config.json с CORS
    location = /app-config.json {
        add_header Access-Control-Allow-Origin "*";
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
        
        ln -sf "$NGINX_AVAILABLE/bedolaga-webhook" "$NGINX_ENABLED/bedolaga-webhook"
        print_success "Конфигурация webhook создана"
    fi
    
    # Конфигурация для miniapp домена
    if [ -n "$MINIAPP_DOMAIN" ]; then
        print_info "Создание конфигурации для $MINIAPP_DOMAIN"
        
        cat > "$NGINX_AVAILABLE/bedolaga-miniapp" << EOF
# Remnawave Bedolaga Bot - Mini App
server {
    listen 80;
    server_name ${MINIAPP_DOMAIN};
    
    client_max_body_size 32m;
    
    # Все запросы проксируем на бота (он сам отдаёт статику miniapp)
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
    }
    
    # app-config.json с CORS
    location = /app-config.json {
        add_header Access-Control-Allow-Origin "*";
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
        
        ln -sf "$NGINX_AVAILABLE/bedolaga-miniapp" "$NGINX_ENABLED/bedolaga-miniapp"
        print_success "Конфигурация miniapp создана"
    fi
    
    # Проверка конфигурации
    nginx -t
    systemctl reload nginx
    print_success "Nginx перезагружен"
}

# Получение SSL сертификатов
setup_ssl() {
    if [ -z "$WEBHOOK_DOMAIN" ] && [ -z "$MINIAPP_DOMAIN" ]; then
        return
    fi
    
    print_step "Настройка SSL сертификатов"
    
    echo -e "${YELLOW}Для получения SSL сертификатов необходимо:${NC}"
    echo -e "${YELLOW}1. Домены должны быть направлены на этот сервер${NC}"
    echo -e "${YELLOW}2. Порт 80 должен быть открыт${NC}"
    echo
    
    # Функция получения сертификата для одного домена
    get_ssl_for_domain() {
        local domain=$1
        local email=$2
        
        echo
        print_info "Проверка DNS для $domain..."
        
        if ! check_domain_dns "$domain"; then
            echo
            echo -e "${YELLOW}   DNS для $domain не настроен правильно.${NC}"
            echo -e "${YELLOW}   Варианты:${NC}"
            echo -e "${YELLOW}   1) Попробовать получить сертификат всё равно${NC}"
            echo -e "${YELLOW}   2) Пропустить этот домен${NC}"
            echo
            read -p "   Выберите (1/2): " ssl_choice < /dev/tty
            
            if [ "$ssl_choice" != "1" ]; then
                print_info "Пропускаем SSL для $domain"
                return 1
            fi
        fi
        
        print_success "DNS для $domain настроен правильно"
        print_info "Получение сертификата для $domain..."
        
        # Если nginx панели в host режиме - используем standalone
        if [ "$PANEL_NGINX_HOST_MODE" = "true" ]; then
            print_info "Используем standalone режим (nginx панели занимает порт 443)"
            
            # Останавливаем nginx панели временно
            print_info "Временная остановка nginx панели..."
            docker stop remnawave-nginx 2>/dev/null || true
            
            # Также останавливаем системный nginx если работает
            systemctl stop nginx 2>/dev/null || true
            
            sleep 2
            
            if certbot certonly --standalone -d "$domain" --email "$email" --agree-tos --non-interactive; then
                print_success "SSL сертификат для $domain получен!"
                
                # Запускаем nginx обратно
                docker start remnawave-nginx 2>/dev/null || true
                systemctl start nginx 2>/dev/null || true
                
                return 0
            else
                print_error "Не удалось получить сертификат для $domain"
                # Запускаем nginx обратно в любом случае
                docker start remnawave-nginx 2>/dev/null || true
                systemctl start nginx 2>/dev/null || true
                
                echo -e "${YELLOW}   Возможные причины:${NC}"
                echo -e "${YELLOW}   - DNS ещё не обновился (подождите 5-10 минут)${NC}"
                echo -e "${YELLOW}   - Порт 80 заблокирован файрволом${NC}"
                echo -e "${YELLOW}   - Домен указывает на другой IP${NC}"
                echo
                echo -e "${CYAN}   Вы можете получить сертификат позже командой:${NC}"
                echo -e "${CYAN}   docker stop remnawave-nginx && certbot certonly --standalone -d $domain && docker start remnawave-nginx${NC}"
                return 1
            fi
        else
            # Стандартный режим через системный nginx
            if certbot --nginx -d "$domain" --email "$email" --agree-tos --non-interactive; then
                print_success "SSL сертификат для $domain получен!"
                return 0
            else
                print_error "Не удалось получить сертификат для $domain"
                echo -e "${YELLOW}   Возможные причины:${NC}"
                echo -e "${YELLOW}   - DNS ещё не обновился (подождите 5-10 минут)${NC}"
                echo -e "${YELLOW}   - Порт 80 заблокирован файрволом${NC}"
                echo -e "${YELLOW}   - Домен указывает на другой IP${NC}"
                echo
                echo -e "${CYAN}   Вы можете получить сертификат позже командой:${NC}"
                echo -e "${CYAN}   certbot --nginx -d $domain${NC}"
                return 1
            fi
        fi
    }
    
    if confirm "Получить SSL сертификаты сейчас?"; then
        # Валидация email
        SSL_EMAIL=""
        while [ -z "$SSL_EMAIL" ] || [[ ! "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
            read -p "Введите email для Let's Encrypt: " SSL_EMAIL < /dev/tty
            if [[ ! "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                print_error "Неверный формат email. Попробуйте снова."
            fi
        done
        
        SSL_SUCCESS=false
        
        if [ -n "$WEBHOOK_DOMAIN" ]; then
            if get_ssl_for_domain "$WEBHOOK_DOMAIN" "$SSL_EMAIL"; then
                SSL_SUCCESS=true
            fi
        fi
        
        if [ -n "$MINIAPP_DOMAIN" ]; then
            if get_ssl_for_domain "$MINIAPP_DOMAIN" "$SSL_EMAIL"; then
                SSL_SUCCESS=true
            fi
        fi
        
        if [ "$SSL_SUCCESS" = true ]; then
            # Настройка автообновления
            systemctl enable certbot.timer 2>/dev/null || true
            systemctl start certbot.timer 2>/dev/null || true
            print_success "SSL сертификаты настроены"
            
            # Если использовали nginx панели - нужно перезапустить его чтобы подхватить новые серты
            if [ "$PANEL_NGINX_HOST_MODE" = "true" ]; then
                print_info "Перезапуск nginx панели для применения сертификатов..."
                cd "$REMNAWAVE_PANEL_DIR"
                docker compose restart remnawave-nginx 2>/dev/null || docker restart remnawave-nginx 2>/dev/null
            fi
        else
            print_warning "SSL сертификаты не были получены"
            echo -e "${CYAN}   Вы можете получить их позже командой:${NC}"
            if [ "$PANEL_NGINX_HOST_MODE" = "true" ]; then
                echo -e "${CYAN}   docker stop remnawave-nginx && certbot certonly --standalone -d yourdomain.com && docker start remnawave-nginx${NC}"
            else
                echo -e "${CYAN}   certbot --nginx -d yourdomain.com${NC}"
            fi
        fi
    else
        print_info "SSL сертификаты можно получить позже командой:"
        if [ "$PANEL_NGINX_HOST_MODE" = "true" ]; then
            echo -e "${CYAN}  docker stop remnawave-nginx && certbot certonly --standalone -d yourdomain.com && docker start remnawave-nginx${NC}"
        else
            echo -e "${CYAN}  certbot --nginx -d yourdomain.com${NC}"
        fi
    fi
}

# Настройка firewall
setup_firewall() {
    print_step "Настройка Firewall (UFW)"
    
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH
    ufw allow 22/tcp
    
    # HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    ufw --force enable
    
    print_success "Firewall настроен"
    ufw status
}

# Запуск Docker контейнеров
start_docker() {
    print_step "Запуск Docker контейнеров"
    
    cd "$INSTALL_DIR"
    
    # Остановка существующих контейнеров
    docker compose down 2>/dev/null || true
    docker compose -f docker-compose.local.yml down 2>/dev/null || true
    
    # Выбор docker-compose файла
    COMPOSE_FILE="docker-compose.yml"
    
    if [ "$PANEL_INSTALLED_LOCALLY" = "true" ]; then
        # Вариант 2: Бот на одном сервере с панелью
        print_info "Настройка подключения к сети панели Remnawave..."
        
        # Проверяем и подготавливаем сеть
        prepare_panel_network
        
        # Проверяем существует ли docker-compose.local.yml
        if [ -f "docker-compose.local.yml" ]; then
            # Адаптируем под реальное имя сети если оно отличается
            adapt_compose_network "docker-compose.local.yml"
            COMPOSE_FILE="docker-compose.local.yml"
            print_info "Используем docker-compose.local.yml для подключения к сети панели"
        else
            print_warning "docker-compose.local.yml не найден, создаём..."
            create_local_compose
            COMPOSE_FILE="docker-compose.local.yml"
        fi
    else
        # Вариант 1: Бот на отдельном сервере
        print_info "Отдельная установка бота (без сети панели)..."
        
        # Используем или создаём стандартный docker-compose.yml
        if [ ! -f "docker-compose.yml" ]; then
            print_warning "docker-compose.yml не найден, создаём..."
            create_standalone_compose
        fi
        COMPOSE_FILE="docker-compose.yml"
        print_info "Используем docker-compose.yml для отдельной установки"
    fi
    
    # Сборка и запуск
    print_info "Запуск: docker compose -f $COMPOSE_FILE up -d --build"
    docker compose -f "$COMPOSE_FILE" up -d --build
    
    print_info "Ожидание запуска контейнеров..."
    sleep 10
    
    # Проверка статуса
    docker compose -f "$COMPOSE_FILE" ps
    
    # ВАЖНО: Принудительное подключение к сети панели после запуска
    if [ "$PANEL_INSTALLED_LOCALLY" = "true" ]; then
        ensure_network_connection
        verify_panel_connection
        # nginx уже пересоздан ранее в main() после add_ssl_to_panel_compose
    fi
    
    # Создаём скрипт-обёртку для docker compose
    if [ "$COMPOSE_FILE" != "docker-compose.yml" ]; then
        cat > dc.sh << EOF
#!/bin/bash
cd "$INSTALL_DIR"
docker compose -f $COMPOSE_FILE "\$@"
EOF
        chmod +x dc.sh
        print_info "Создан скрипт dc.sh для удобного управления"
    fi
    
    print_success "Контейнеры запущены"
}

# Принудительное подключение контейнеров к сети панели
ensure_network_connection() {
    local network="${REMNAWAVE_DOCKER_NETWORK:-remnawave-network}"
    
    print_info "Проверка подключения контейнеров к сети $network..."
    
    # Проверяем существует ли сеть
    if ! docker network inspect "$network" &>/dev/null; then
        print_warning "Сеть $network не существует, создаём..."
        docker network create "$network" 2>/dev/null || true
    fi
    
    # Подключаем контейнер бота если не подключен
    local bot_networks=$(docker inspect remnawave_bot --format '{{range $net, $config := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null)
    if [[ ! "$bot_networks" =~ "$network" ]]; then
        print_info "Подключаем remnawave_bot к сети $network..."
        docker network connect "$network" remnawave_bot 2>/dev/null || true
    else
        print_success "remnawave_bot уже подключен к $network"
    fi
    
    # Подключаем контейнер панели если не подключен
    if docker ps --format '{{.Names}}' | grep -q "^remnawave$"; then
        local panel_networks=$(docker inspect remnawave --format '{{range $net, $config := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null)
        if [[ ! "$panel_networks" =~ "$network" ]]; then
            print_info "Подключаем remnawave к сети $network..."
            docker network connect "$network" remnawave 2>/dev/null || true
        else
            print_success "remnawave уже подключен к $network"
        fi
    fi
    
    # Небольшая пауза для применения сетевых настроек
    sleep 2
}

# Перезапуск nginx панели для применения новых сертификатов
restart_panel_nginx() {
    if [ -z "$REMNAWAVE_PANEL_DIR" ]; then
        print_warning "Директория панели не определена"
        return 1
    fi
    
    print_info "Пересоздание nginx панели для применения новых volumes..."
    
    cd "$REMNAWAVE_PANEL_DIR"
    
    # ВАЖНО: используем "up -d" а не "restart" - это пересоздаёт контейнер с новыми volumes
    docker compose up -d remnawave-nginx 2>&1
    
    # Ждём запуска
    sleep 5
    
    # Проверяем статус
    if docker ps --format '{{.Names}}' | grep -q "remnawave-nginx"; then
        # Контейнер запущен - проверим что он не в цикле перезапуска
        local status=$(docker inspect remnawave-nginx --format '{{.State.Status}}' 2>/dev/null)
        local restart_count=$(docker inspect remnawave-nginx --format '{{.RestartCount}}' 2>/dev/null)
        
        if [ "$status" = "running" ] && [ "${restart_count:-0}" -lt 3 ]; then
            print_success "Nginx панели запущен"
            cd "$INSTALL_DIR"
            return 0
        fi
    fi
    
    # Nginx не запустился - показываем ошибку
    print_error "Nginx панели не запустился! Проверьте:"
    print_error "  docker logs remnawave-nginx --tail 20"
    
    # Показываем последние строки лога
    echo
    docker logs remnawave-nginx --tail 5 2>&1 | grep -i "emerg\|error" | head -3
    echo
    
    cd "$INSTALL_DIR"
    return 1
}

# Подготовка сети для подключения к панели
prepare_panel_network() {
    # Проверяем существует ли сеть remnawave-network
    if docker network inspect "remnawave-network" &>/dev/null; then
        print_success "Сеть remnawave-network найдена"
        REMNAWAVE_DOCKER_NETWORK="remnawave-network"
        return 0
    fi
    
    # Если remnawave-network не существует, но есть другая сеть панели
    if [ -n "$REMNAWAVE_DOCKER_NETWORK" ] && [ "$REMNAWAVE_DOCKER_NETWORK" != "remnawave-network" ]; then
        print_info "Сеть панели: $REMNAWAVE_DOCKER_NETWORK (не remnawave-network)"
        
        echo -e "${WHITE}Варианты подключения к сети панели:${NC}"
        echo -e "  ${CYAN}1)${NC} Создать сеть remnawave-network и подключить контейнер панели ${YELLOW}(рекомендуется)${NC}"
        echo -e "  ${CYAN}2)${NC} Адаптировать конфиг бота под существующую сеть ($REMNAWAVE_DOCKER_NETWORK)"
        echo
        
        while true; do
            read -p "Ваш выбор (1/2): " net_choice < /dev/tty
            case $net_choice in
                1)
                    create_remnawave_network
                    break
                    ;;
                2)
                    print_info "Будет использована сеть: $REMNAWAVE_DOCKER_NETWORK"
                    break
                    ;;
                *)
                    echo -e "${YELLOW}   Пожалуйста, введите 1 или 2${NC}"
                    ;;
            esac
        done
    elif [ -z "$REMNAWAVE_DOCKER_NETWORK" ]; then
        # Сеть не найдена вообще
        print_warning "Сеть панели не найдена"
        
        if confirm "Создать сеть remnawave-network?"; then
            docker network create remnawave-network 2>/dev/null || true
            REMNAWAVE_DOCKER_NETWORK="remnawave-network"
            print_success "Создана сеть remnawave-network"
            
            # Подключаем контейнер панели если он существует
            if docker ps --format '{{.Names}}' | grep -q "^remnawave$"; then
                docker network connect remnawave-network remnawave 2>/dev/null || true
                print_info "Контейнер remnawave подключен к сети"
            fi
        else
            print_warning "Бот может не иметь связи с панелью!"
        fi
    fi
}

# Создание сети remnawave-network и подключение панели
create_remnawave_network() {
    print_info "Создание сети remnawave-network..."
    
    # Создаём сеть
    docker network create remnawave-network 2>/dev/null || true
    
    # Подключаем контейнер remnawave к новой сети
    if docker ps --format '{{.Names}}' | grep -q "^remnawave$"; then
        docker network connect remnawave-network remnawave 2>/dev/null || true
        print_success "Контейнер remnawave подключен к remnawave-network"
    else
        print_warning "Контейнер remnawave не запущен - подключите его позже"
    fi
    
    REMNAWAVE_DOCKER_NETWORK="remnawave-network"
    print_success "Сеть remnawave-network создана"
}

# Адаптация compose файла под реальную сеть
adapt_compose_network() {
    local compose_file="$1"
    
    # Если сеть уже remnawave-network - ничего не меняем
    if [ "$REMNAWAVE_DOCKER_NETWORK" = "remnawave-network" ] || [ -z "$REMNAWAVE_DOCKER_NETWORK" ]; then
        return 0
    fi
    
    print_info "Адаптация $compose_file под сеть $REMNAWAVE_DOCKER_NETWORK..."
    
    # Создаём бэкап
    cp "$compose_file" "${compose_file}.backup"
    
    # Заменяем имя сети в файле
    sed -i "s/remnawave-network/$REMNAWAVE_DOCKER_NETWORK/g" "$compose_file"
    
    print_success "Compose файл адаптирован под сеть $REMNAWAVE_DOCKER_NETWORK"
}

# Проверка связи с панелью
verify_panel_connection() {
    print_info "Проверка связи с панелью Remnawave..."
    
    # Быстрая проверка DNS — без retry, просто информация
    if docker exec remnawave_bot sh -c "getent hosts remnawave" &>/dev/null; then
        print_success "DNS: контейнер remnawave найден в сети"
    else
        print_warning "DNS: контейнер remnawave не найден в сети"
        print_info "Проверьте позже: docker exec remnawave_bot sh -c 'getent hosts remnawave'"
    fi
}

# Создание docker-compose.local.yml если его нет
create_local_compose() {
    # Используем актуальное имя сети, по умолчанию remnawave-network
    local NETWORK_NAME="${REMNAWAVE_DOCKER_NETWORK:-remnawave-network}"
    
    cat > docker-compose.local.yml << LOCALEOF
services:
  postgres:
    image: postgres:15-alpine
    container_name: remnawave_bot_db
    restart: unless-stopped
    environment:
      POSTGRES_DB: \${POSTGRES_DB:-remnawave_bot}
      POSTGRES_USER: \${POSTGRES_USER:-remnawave_user}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-secure_password_123}
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - bot_network
      - ${NETWORK_NAME}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER:-remnawave_user} -d \${POSTGRES_DB:-remnawave_bot}"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 30s

  redis:
    image: redis:7-alpine
    container_name: remnawave_bot_redis
    restart: unless-stopped
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    networks:
      - bot_network
      - ${NETWORK_NAME}
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  bot:
    build: .
    container_name: remnawave_bot
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    env_file:
      - .env
    environment:
      DOCKER_ENV: "true"
      DATABASE_MODE: "auto"
      POSTGRES_HOST: "postgres"
      POSTGRES_PORT: "5432"
      POSTGRES_DB: "\${POSTGRES_DB:-remnawave_bot}"
      POSTGRES_USER: "\${POSTGRES_USER:-remnawave_user}"
      POSTGRES_PASSWORD: "\${POSTGRES_PASSWORD:-secure_password_123}"
      REDIS_URL: "redis://redis:6379/0"
      TZ: "Europe/Moscow"
      LOCALES_PATH: "\${LOCALES_PATH:-/app/locales}"
    volumes:
      - ./logs:/app/logs:rw
      - ./data:/app/data:rw
      - ./locales:/app/locales:rw
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
      - ./vpn_logo.png:/app/vpn_logo.png:ro
    ports:
      - "\${WEB_API_PORT:-8080}:8080"
    networks:
      - bot_network
      - ${NETWORK_NAME}
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:8080/health || exit 1"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 30s

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local

networks:
  bot_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1
  
  ${NETWORK_NAME}:
    name: ${NETWORK_NAME}
    external: true
LOCALEOF
    print_success "Создан docker-compose.local.yml (сеть: $NETWORK_NAME)"
}

# Создание скриптов управления
create_management_scripts() {
    print_step "Создание скриптов управления"
    
    cd "$INSTALL_DIR"
    
    # Определяем какой compose файл использовать
    local COMPOSE_FILE="docker-compose.yml"
    if [ "$PANEL_INSTALLED_LOCALLY" = "true" ] && [ -f "docker-compose.local.yml" ]; then
        COMPOSE_FILE="docker-compose.local.yml"
    fi
    
    # Сохраняем информацию о конфигурации
    cat > .install_config << EOF
# Конфигурация установки (сгенерировано автоустановщиком)
INSTALL_DIR="$INSTALL_DIR"
COMPOSE_FILE="$COMPOSE_FILE"
PANEL_INSTALLED_LOCALLY="$PANEL_INSTALLED_LOCALLY"
REMNAWAVE_DOCKER_NETWORK="${REMNAWAVE_DOCKER_NETWORK:-remnawave-network}"
REMNAWAVE_PANEL_DIR="$REMNAWAVE_PANEL_DIR"
EOF
    
    # Скрипт обновления (с сохранением локальных настроек и подключением к сети)
    cat > update.sh << 'UPDATEEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Загружаем конфигурацию
if [ -f ".install_config" ]; then
    source .install_config
else
    COMPOSE_FILE="docker-compose.yml"
    [ -f "docker-compose.local.yml" ] && COMPOSE_FILE="docker-compose.local.yml"
fi

echo "🔄 Обновление Remnawave Bedolaga Bot..."

# Сохраняем локальные изменения если есть
if [ -f "docker-compose.local.yml" ]; then
    cp docker-compose.local.yml docker-compose.local.yml.backup
    echo "📋 Сохранён бэкап docker-compose.local.yml"
fi

# Обновляем код
git fetch --tags
git pull origin main

# Восстанавливаем локальные настройки если были
if [ -f "docker-compose.local.yml.backup" ]; then
    if grep -q "external: true" docker-compose.local.yml.backup; then
        cp docker-compose.local.yml.backup docker-compose.local.yml
        echo "📋 Восстановлен docker-compose.local.yml"
    fi
    rm -f docker-compose.local.yml.backup
fi

# Перезапускаем
docker compose -f "$COMPOSE_FILE" down
docker compose -f "$COMPOSE_FILE" up -d --build

# Ждём запуска
sleep 10

# Подключаем к сети панели если нужно
if [ "$PANEL_INSTALLED_LOCALLY" = "true" ] && [ -n "$REMNAWAVE_DOCKER_NETWORK" ]; then
    echo "🔗 Проверка подключения к сети панели..."
    docker network connect "$REMNAWAVE_DOCKER_NETWORK" remnawave_bot 2>/dev/null && echo "✅ Подключено к $REMNAWAVE_DOCKER_NETWORK" || echo "ℹ️ Уже подключено"
fi

echo "✅ Обновление завершено!"
docker compose -f "$COMPOSE_FILE" logs -f --tail=50
UPDATEEOF
    chmod +x update.sh
    
    # Скрипт просмотра логов
    cat > logs.sh << 'LOGSEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[ -f ".install_config" ] && source .install_config
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
[ -f "docker-compose.local.yml" ] && COMPOSE_FILE="docker-compose.local.yml"
docker compose -f "$COMPOSE_FILE" logs -f --tail=100 "$@"
LOGSEOF
    chmod +x logs.sh
    
    # Скрипт перезапуска (с подключением к сети)
    cat > restart.sh << 'RESTARTEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[ -f ".install_config" ] && source .install_config
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
[ -f "docker-compose.local.yml" ] && COMPOSE_FILE="docker-compose.local.yml"

echo "🔄 Перезапуск бота..."
docker compose -f "$COMPOSE_FILE" restart

# Ждём запуска
sleep 5

# Подключаем к сети панели если нужно
if [ "$PANEL_INSTALLED_LOCALLY" = "true" ] && [ -n "$REMNAWAVE_DOCKER_NETWORK" ]; then
    echo "🔗 Проверка подключения к сети панели..."
    docker network connect "$REMNAWAVE_DOCKER_NETWORK" remnawave_bot 2>/dev/null && echo "✅ Подключено к $REMNAWAVE_DOCKER_NETWORK" || echo "ℹ️ Уже подключено"
fi

echo "✅ Бот перезапущен!"
docker compose -f "$COMPOSE_FILE" ps
RESTARTEOF
    chmod +x restart.sh
    
    # Скрипт остановки
    cat > stop.sh << 'STOPEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[ -f ".install_config" ] && source .install_config
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
[ -f "docker-compose.local.yml" ] && COMPOSE_FILE="docker-compose.local.yml"
echo "🛑 Остановка бота..."
docker compose -f "$COMPOSE_FILE" down
echo "✅ Бот остановлен!"
STOPEOF
    chmod +x stop.sh
    
    # Скрипт запуска
    cat > start.sh << 'STARTEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[ -f ".install_config" ] && source .install_config
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
[ -f "docker-compose.local.yml" ] && COMPOSE_FILE="docker-compose.local.yml"
echo "🚀 Запуск бота..."
docker compose -f "$COMPOSE_FILE" up -d
echo "✅ Бот запущен!"
docker compose -f "$COMPOSE_FILE" ps
STARTEOF
    chmod +x start.sh
    
    # Скрипт статуса
    cat > status.sh << 'STATUSEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[ -f ".install_config" ] && source .install_config
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
[ -f "docker-compose.local.yml" ] && COMPOSE_FILE="docker-compose.local.yml"
echo "📊 Статус Remnawave Bedolaga Bot:"
echo ""
docker compose -f "$COMPOSE_FILE" ps
echo ""
echo "📈 Использование ресурсов:"
docker stats --no-stream remnawave_bot remnawave_bot_db remnawave_bot_redis 2>/dev/null || docker stats --no-stream
STATUSEOF
    chmod +x status.sh
    
    # Скрипт диагностики сети (новый!)
    cat > network-check.sh << 'NETEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[ -f ".install_config" ] && source .install_config

echo "🔍 Диагностика сети Remnawave Bedolaga Bot"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📦 Контейнеры бота:"
docker ps --filter "name=remnawave_bot" --format "  {{.Names}}: {{.Status}}"
echo ""

echo "🌐 Сети контейнера бота:"
docker inspect remnawave_bot --format '{{range $net, $config := .NetworkSettings.Networks}}  - {{$net}} (IP: {{$config.IPAddress}}){{"\n"}}{{end}}' 2>/dev/null || echo "  (контейнер не найден)"
echo ""

echo "📦 Контейнер панели Remnawave:"
docker ps --filter "name=remnawave" --filter "name=!remnawave_bot" --format "  {{.Names}}: {{.Status}}"
echo ""

echo "🌐 Сети контейнера панели:"
docker inspect remnawave --format '{{range $net, $config := .NetworkSettings.Networks}}  - {{$net}} (IP: {{$config.IPAddress}}){{"\n"}}{{end}}' 2>/dev/null || echo "  (контейнер не найден)"
echo ""

echo "🔗 Проверка DNS (из контейнера бота):"
if docker exec remnawave_bot sh -c "getent hosts remnawave" 2>/dev/null; then
    echo "  ✅ DNS работает"
else
    echo "  ❌ DNS не работает - контейнер remnawave не найден в сети"
fi
echo ""

echo "🔗 Проверка HTTP соединения с панелью:"
if docker exec remnawave_bot sh -c "timeout 5 wget -q --spider http://remnawave:3000/" 2>/dev/null; then
    echo "  ✅ HTTP соединение установлено"
else
    echo "  ❌ Не удалось подключиться к http://remnawave:3000"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
NETEOF
    chmod +x network-check.sh
    
    # Скрипт бэкапа
    cat > backup.sh << 'BACKUPEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
BACKUP_DIR="./backups"
BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S).tar.gz"
mkdir -p $BACKUP_DIR
echo "📦 Создание бэкапа..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME" .env .install_config data/ 2>/dev/null || tar -czf "$BACKUP_DIR/$BACKUP_NAME" .env data/
echo "✅ Бэкап создан: $BACKUP_DIR/$BACKUP_NAME"
# Удаление старых бэкапов (старше 7 дней)
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete
echo "🗑️ Старые бэкапы удалены"
BACKUPEOF
    chmod +x backup.sh
    
    print_success "Скрипты управления созданы"
}

# Финальная информация
print_final_info() {
    print_step "Установка завершена!"
    
    echo -e "${WHITE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     🎉 REMNAWAVE BEDOLAGA BOT УСПЕШНО УСТАНОВЛЕН! 🎉        ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}📁 Директория установки:${NC} $INSTALL_DIR"
    
    # Информация о подключении к панели
    if [ "$PANEL_INSTALLED_LOCALLY" = "true" ] && [ -n "$REMNAWAVE_DOCKER_NETWORK" ]; then
        echo -e "${CYAN}🔗 Подключение к панели:${NC} через Docker сеть ${GREEN}$REMNAWAVE_DOCKER_NETWORK${NC}"
        echo -e "${CYAN}🌐 URL панели:${NC} $REMNAWAVE_API_URL"
    fi
    
    echo
    echo -e "${CYAN}🔧 Полезные команды:${NC}"
    echo -e "   ${GREEN}cd $INSTALL_DIR${NC}"
    echo -e "   ${GREEN}./logs.sh${NC}           - Просмотр логов"
    echo -e "   ${GREEN}./restart.sh${NC}        - Перезапуск бота"
    echo -e "   ${GREEN}./start.sh${NC}          - Запуск бота"
    echo -e "   ${GREEN}./stop.sh${NC}           - Остановка бота"
    echo -e "   ${GREEN}./update.sh${NC}         - Обновление бота"
    echo -e "   ${GREEN}./status.sh${NC}         - Статус контейнеров"
    echo -e "   ${GREEN}./backup.sh${NC}         - Создание бэкапа"
    echo -e "   ${GREEN}./network-check.sh${NC}  - Диагностика сети"
    echo
    echo -e "${CYAN}🐳 Docker команды:${NC}"
    echo -e "   ${GREEN}docker compose ps${NC}           - Статус контейнеров"
    echo -e "   ${GREEN}docker compose logs -f bot${NC}  - Логи бота"
    echo -e "   ${GREEN}docker compose restart${NC}      - Перезапуск"
    echo -e "   ${GREEN}make help${NC}                   - Все доступные команды"
    echo
    
    if [ -n "$WEBHOOK_DOMAIN" ]; then
        echo -e "${CYAN}🌐 Webhook URL:${NC} https://$WEBHOOK_DOMAIN/webhook"
        echo -e "${CYAN}📊 Health Check:${NC} https://$WEBHOOK_DOMAIN/health"
    fi
    
    if [ -n "$MINIAPP_DOMAIN" ]; then
        echo -e "${CYAN}📱 Mini App:${NC} https://$MINIAPP_DOMAIN"
    fi
    
    # Информация о режиме nginx
    if [ "$PANEL_NGINX_HOST_MODE" = "true" ]; then
        echo
        echo -e "${CYAN}🔧 Nginx режим:${NC} конфигурация добавлена в nginx панели"
        echo -e "${YELLOW}   Файл: $PANEL_NGINX_CONF${NC}"
        echo -e "${YELLOW}   Перезапуск nginx: cd $REMNAWAVE_PANEL_DIR && docker compose restart remnawave-nginx${NC}"
    fi
    
    echo
    echo -e "${YELLOW}⚠️  ВАЖНО: После первого запуска выполните:${NC}"
    echo -e "   1. Зайдите в бот и нажмите /start"
    echo -e "   2. Перейдите в Админ панель → Подписки → Управление серверами"
    echo -e "   3. Нажмите 'Синхронизация' для загрузки серверов из Remnawave"
    echo
    echo -e "${PURPLE}📚 Документация: https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot${NC}"
    echo -e "${PURPLE}💬 Telegram чат: https://t.me/+wTdMtSWq8YdmZmVi${NC}"
    echo
}

# Показать логи бота после установки
ask_show_logs() {
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Хотите посмотреть логи бота чтобы убедиться что всё запустилось?${NC}"
    echo
    
    while true; do
        read -p "Показать логи бота? (y/n): " -n 1 show_logs < /dev/tty
        echo
        case "$show_logs" in
            [yY])
                echo
                echo -e "${GREEN}📋 Логи бота (Ctrl+C для выхода):${NC}"
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                cd "$INSTALL_DIR"
                # Определяем какой compose файл использовать
                local COMPOSE_FILE="docker-compose.yml"
                if [ "$PANEL_INSTALLED_LOCALLY" = "true" ] && [ -f "docker-compose.local.yml" ]; then
                    COMPOSE_FILE="docker-compose.local.yml"
                fi
                docker compose -f "$COMPOSE_FILE" logs -f --tail=150 bot
                break
                ;;
            [nN])
                echo -e "${GREEN}✅ Установка завершена! Вы можете посмотреть логи позже командой: ./logs.sh${NC}"
                break
                ;;
            *)
                echo -e "${YELLOW}   Пожалуйста, введите 'y' или 'n'${NC}"
                ;;
        esac
    done
}

# Главная функция
main() {
    print_banner
    
    check_root
    detect_os
    
    echo -e "\n${WHITE}Этот скрипт выполнит:${NC}"
    echo -e "  1. Обновление системы"
    echo -e "  2. Установку Docker, Nginx и необходимых пакетов"
    echo -e "  3. Клонирование репозитория"
    echo -e "  4. Интерактивную настройку бота"
    echo -e "  5. Настройку Nginx и SSL (опционально)"
    echo -e "  6. Запуск Docker контейнеров"
    echo
    
    if ! confirm "Продолжить установку?"; then
        echo "Установка отменена"
        exit 0
    fi
    
    # Выбор директории и проверка панели
    select_install_dir
    check_remnawave_panel
    
    update_system
    install_base_packages
    install_docker
    install_nginx
    clone_repository
    create_directories
    interactive_setup
    create_env_file
    setup_miniapp_files
    setup_nginx
    setup_ssl
    
    # Добавляем SSL сертификаты в docker-compose панели ПОСЛЕ их создания
    # и ПЕРЕСОЗДАЁМ nginx чтобы применить новые volumes
    if [ "$PANEL_NGINX_HOST_MODE" = "true" ]; then
        add_ssl_to_panel_compose
        
        # Пересоздаём nginx панели чтобы применить новые volumes
        print_step "Применение конфигурации nginx"
        restart_panel_nginx
        
        # Проверяем что nginx запустился и работает
        sleep 3
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "remnawave-nginx"; then
            if ! docker inspect remnawave-nginx --format '{{.State.Restarting}}' 2>/dev/null | grep -q "true"; then
                print_success "Nginx панели работает корректно"
            else
                print_error "Nginx в цикле перезапуска! Проверьте сертификаты."
                print_error "Команда: docker logs remnawave-nginx --tail 10"
            fi
        else
            print_error "Nginx панели не запущен!"
        fi
    fi
    
    setup_firewall
    start_docker
    create_management_scripts
    print_final_info
    ask_show_logs
}

# Запуск
main "$@"
