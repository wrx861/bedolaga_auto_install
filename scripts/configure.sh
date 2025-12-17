#!/bin/bash

# ===============================================
# ⚙️ REMNAWAVE BEDOLAGA BOT - КОНФИГУРАТОР
# ===============================================
# Интерактивная настройка существующей установки
# ===============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Автоопределение директории установки
if [ -d "/opt/remnawave-bedolaga-telegram-bot" ]; then
    INSTALL_DIR="/opt/remnawave-bedolaga-telegram-bot"
elif [ -d "/root/remnawave-bedolaga-telegram-bot" ]; then
    INSTALL_DIR="/root/remnawave-bedolaga-telegram-bot"
else
    if [ -f "./docker-compose.yml" ] && [ -f "./.env" ]; then
        INSTALL_DIR="$(pwd)"
    else
        echo -e "${RED}❌ Бот не установлен!${NC}"
        echo -e "${YELLOW}Сначала выполните установку.${NC}"
        exit 1
    fi
fi

ENV_FILE="$INSTALL_DIR/.env"

print_menu() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     ⚙️ REMNAWAVE BEDOLAGA BOT - КОНФИГУРАТОР ⚙️              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${WHITE}Выберите действие:${NC}"
    echo
    echo -e "  ${CYAN}1)${NC} Изменить BOT_TOKEN"
    echo -e "  ${CYAN}2)${NC} Изменить ADMIN_IDS"
    echo -e "  ${CYAN}3)${NC} Изменить настройки Remnawave API"
    echo -e "  ${CYAN}4)${NC} Настроить платежные системы"
    echo -e "  ${CYAN}5)${NC} Настроить уведомления"
    echo -e "  ${CYAN}6)${NC} Настроить webhook"
    echo -e "  ${CYAN}7)${NC} Показать текущую конфигурацию"
    echo -e "  ${CYAN}8)${NC} Перезапустить бота"
    echo -e "  ${CYAN}9)${NC} Подключить SSL сертификаты к nginx панели"
    echo -e "  ${CYAN}10)${NC} Диагностика сети (если не видит панель)"
    echo -e "  ${CYAN}0)${NC} Выход"
    echo
}

get_env_value() {
    local key=$1
    grep "^$key=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'"
}

set_env_value() {
    local key=$1
    local value=$2
    
    if grep -q "^$key=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^$key=.*|$key=$value|" "$ENV_FILE"
    else
        echo "$key=$value" >> "$ENV_FILE"
    fi
}

edit_bot_token() {
    echo -e "${CYAN}Текущий BOT_TOKEN:${NC} $(get_env_value BOT_TOKEN | head -c 20)..."
    echo
    read -p "Новый BOT_TOKEN (Enter для отмены): " NEW_VALUE
    if [ -n "$NEW_VALUE" ]; then
        set_env_value "BOT_TOKEN" "$NEW_VALUE"
        echo -e "${GREEN}✅ BOT_TOKEN обновлен${NC}"
    fi
}

edit_admin_ids() {
    echo -e "${CYAN}Текущие ADMIN_IDS:${NC} $(get_env_value ADMIN_IDS)"
    echo -e "${YELLOW}Формат: ID через запятую (123456789,987654321)${NC}"
    echo
    read -p "Новые ADMIN_IDS (Enter для отмены): " NEW_VALUE
    if [ -n "$NEW_VALUE" ]; then
        set_env_value "ADMIN_IDS" "$NEW_VALUE"
        echo -e "${GREEN}✅ ADMIN_IDS обновлены${NC}"
    fi
}

edit_remnawave() {
    echo -e "${CYAN}Текущие настройки Remnawave:${NC}"
    echo -e "  API_URL: $(get_env_value REMNAWAVE_API_URL)"
    echo -e "  API_KEY: $(get_env_value REMNAWAVE_API_KEY | head -c 20)..."
    echo -e "  AUTH_TYPE: $(get_env_value REMNAWAVE_AUTH_TYPE)"
    echo -e "  SECRET_KEY (eGames): $(get_env_value REMNAWAVE_SECRET_KEY)"
    echo
    
    read -p "Новый REMNAWAVE_API_URL (Enter для пропуска): " NEW_URL
    if [ -n "$NEW_URL" ]; then
        set_env_value "REMNAWAVE_API_URL" "$NEW_URL"
        echo -e "${GREEN}✅ REMNAWAVE_API_URL обновлен${NC}"
    fi
    
    read -p "Новый REMNAWAVE_API_KEY (Enter для пропуска): " NEW_KEY
    if [ -n "$NEW_KEY" ]; then
        set_env_value "REMNAWAVE_API_KEY" "$NEW_KEY"
        echo -e "${GREEN}✅ REMNAWAVE_API_KEY обновлен${NC}"
    fi
    
    echo
    echo -e "${WHITE}Тип авторизации:${NC}"
    echo -e "  ${CYAN}[1]${NC} api_key (по умолчанию)"
    echo -e "  ${CYAN}[2]${NC} basic_auth"
    read -p "Выберите тип (Enter для пропуска): " AUTH_CHOICE
    if [ "$AUTH_CHOICE" == "1" ]; then
        set_env_value "REMNAWAVE_AUTH_TYPE" "api_key"
        echo -e "${GREEN}✅ Тип авторизации: api_key${NC}"
    elif [ "$AUTH_CHOICE" == "2" ]; then
        set_env_value "REMNAWAVE_AUTH_TYPE" "basic_auth"
        read -p "  REMNAWAVE_USERNAME: " NEW_USER
        read -s -p "  REMNAWAVE_PASSWORD: " NEW_PASS
        echo
        [ -n "$NEW_USER" ] && set_env_value "REMNAWAVE_USERNAME" "$NEW_USER"
        [ -n "$NEW_PASS" ] && set_env_value "REMNAWAVE_PASSWORD" "$NEW_PASS"
        echo -e "${GREEN}✅ Basic Auth настроен${NC}"
    fi
    
    echo
    echo -e "${YELLOW}REMNAWAVE_SECRET_KEY нужен для панелей установленных через eGames${NC}"
    echo -e "${WHITE}Формат: KEY:VALUE (через ДВОЕТОЧИЕ!)${NC}"
    echo -e "${YELLOW}Если в URL панели: ?ABC=XYZ → вводите: ABC:XYZ${NC}"
    read -p "Новый REMNAWAVE_SECRET_KEY (Enter для пропуска, 'delete' для удаления): " NEW_SECRET
    if [ "$NEW_SECRET" == "delete" ]; then
        sed -i '/^REMNAWAVE_SECRET_KEY=/d' "$ENV_FILE"
        echo -e "${GREEN}✅ REMNAWAVE_SECRET_KEY удален${NC}"
    elif [ -n "$NEW_SECRET" ]; then
        # Автозамена = на : если пользователь ввёл через =
        if [[ "$NEW_SECRET" == *"="* ]] && [[ "$NEW_SECRET" != *":"* ]]; then
            NEW_SECRET="${NEW_SECRET/=/:/}"
            echo -e "${YELLOW}⚠️ Автозамена = на : → $NEW_SECRET${NC}"
        fi
        set_env_value "REMNAWAVE_SECRET_KEY" "$NEW_SECRET"
        echo -e "${GREEN}✅ REMNAWAVE_SECRET_KEY обновлен${NC}"
    fi
}

edit_payments() {
    echo -e "${CYAN}Настройка платежных систем:${NC}"
    echo
    echo -e "  1) Telegram Stars"
    echo -e "  2) YooKassa"
    echo -e "  3) CryptoBot"
    echo -e "  4) PayPalych"
    echo -e "  0) Назад"
    echo
    read -p "Выберите систему: " PAYMENT_CHOICE
    
    case $PAYMENT_CHOICE in
        1)
            echo -e "${CYAN}Telegram Stars:${NC}"
            CURRENT=$(get_env_value TELEGRAM_STARS_ENABLED)
            echo -e "  Текущий статус: $CURRENT"
            read -p "  Включить? (true/false): " NEW_VALUE
            if [ -n "$NEW_VALUE" ]; then
                set_env_value "TELEGRAM_STARS_ENABLED" "$NEW_VALUE"
                echo -e "${GREEN}✅ Обновлено${NC}"
            fi
            ;;
        2)
            echo -e "${CYAN}YooKassa:${NC}"
            read -p "  YOOKASSA_ENABLED (true/false): " ENABLED
            read -p "  YOOKASSA_SHOP_ID: " SHOP_ID
            read -p "  YOOKASSA_SECRET_KEY: " SECRET_KEY
            
            [ -n "$ENABLED" ] && set_env_value "YOOKASSA_ENABLED" "$ENABLED"
            [ -n "$SHOP_ID" ] && set_env_value "YOOKASSA_SHOP_ID" "$SHOP_ID"
            [ -n "$SECRET_KEY" ] && set_env_value "YOOKASSA_SECRET_KEY" "$SECRET_KEY"
            echo -e "${GREEN}✅ YooKassa настроена${NC}"
            ;;
        3)
            echo -e "${CYAN}CryptoBot:${NC}"
            read -p "  CRYPTOBOT_ENABLED (true/false): " ENABLED
            read -p "  CRYPTOBOT_API_TOKEN: " TOKEN
            
            [ -n "$ENABLED" ] && set_env_value "CRYPTOBOT_ENABLED" "$ENABLED"
            [ -n "$TOKEN" ] && set_env_value "CRYPTOBOT_API_TOKEN" "$TOKEN"
            echo -e "${GREEN}✅ CryptoBot настроен${NC}"
            ;;
        4)
            echo -e "${CYAN}PayPalych:${NC}"
            read -p "  PAL24_ENABLED (true/false): " ENABLED
            read -p "  PAL24_API_TOKEN: " TOKEN
            read -p "  PAL24_SHOP_ID: " SHOP_ID
            
            [ -n "$ENABLED" ] && set_env_value "PAL24_ENABLED" "$ENABLED"
            [ -n "$TOKEN" ] && set_env_value "PAL24_API_TOKEN" "$TOKEN"
            [ -n "$SHOP_ID" ] && set_env_value "PAL24_SHOP_ID" "$SHOP_ID"
            echo -e "${GREEN}✅ PayPalych настроен${NC}"
            ;;
    esac
}

edit_notifications() {
    echo -e "${CYAN}Настройка уведомлений:${NC}"
    echo -e "  Текущий Chat ID: $(get_env_value ADMIN_NOTIFICATIONS_CHAT_ID)"
    echo -e "  Статус: $(get_env_value ADMIN_NOTIFICATIONS_ENABLED)"
    echo
    
    read -p "ADMIN_NOTIFICATIONS_ENABLED (true/false): " ENABLED
    read -p "ADMIN_NOTIFICATIONS_CHAT_ID: " CHAT_ID
    read -p "ADMIN_NOTIFICATIONS_TOPIC_ID (опционально): " TOPIC_ID
    
    [ -n "$ENABLED" ] && set_env_value "ADMIN_NOTIFICATIONS_ENABLED" "$ENABLED"
    [ -n "$CHAT_ID" ] && set_env_value "ADMIN_NOTIFICATIONS_CHAT_ID" "$CHAT_ID"
    [ -n "$TOPIC_ID" ] && set_env_value "ADMIN_NOTIFICATIONS_TOPIC_ID" "$TOPIC_ID"
    
    echo -e "${GREEN}✅ Уведомления настроены${NC}"
}

edit_webhook() {
    echo -e "${CYAN}Настройка Webhook:${NC}"
    echo -e "  Текущий режим: $(get_env_value BOT_RUN_MODE)"
    echo -e "  Webhook URL: $(get_env_value WEBHOOK_URL)"
    echo
    
    echo -e "${WHITE}Режимы работы:${NC}"
    echo -e "  polling - бот сам опрашивает Telegram"
    echo -e "  webhook - Telegram отправляет обновления на ваш сервер"
    echo -e "  both - оба режима одновременно"
    echo
    
    read -p "BOT_RUN_MODE (polling/webhook/both): " MODE
    if [ "$MODE" == "webhook" ] || [ "$MODE" == "both" ]; then
        read -p "WEBHOOK_URL (https://yourdomain.com): " URL
        [ -n "$URL" ] && set_env_value "WEBHOOK_URL" "$URL"
        set_env_value "WEB_API_ENABLED" "true"
    else
        set_env_value "WEB_API_ENABLED" "false"
    fi
    
    [ -n "$MODE" ] && set_env_value "BOT_RUN_MODE" "$MODE"
    
    echo -e "${GREEN}✅ Webhook настроен${NC}"
}

show_config() {
    echo -e "${CYAN}Текущая конфигурация:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${WHITE}Основные:${NC}"
    echo -e "  BOT_TOKEN: $(get_env_value BOT_TOKEN | head -c 20)..."
    echo -e "  ADMIN_IDS: $(get_env_value ADMIN_IDS)"
    echo
    echo -e "${WHITE}Remnawave:${NC}"
    echo -e "  API_URL: $(get_env_value REMNAWAVE_API_URL)"
    echo -e "  API_KEY: $(get_env_value REMNAWAVE_API_KEY | head -c 20)..."
    echo -e "  AUTH_TYPE: $(get_env_value REMNAWAVE_AUTH_TYPE)"
    local auth_type=$(get_env_value REMNAWAVE_AUTH_TYPE)
    if [ "$auth_type" == "basic_auth" ]; then
        echo -e "  USERNAME: $(get_env_value REMNAWAVE_USERNAME)"
        echo -e "  PASSWORD: ****"
    fi
    local secret_key=$(get_env_value REMNAWAVE_SECRET_KEY)
    if [ -n "$secret_key" ]; then
        echo -e "  SECRET_KEY (eGames): ${YELLOW}установлен${NC}"
    else
        echo -e "  SECRET_KEY (eGames): не установлен"
    fi
    echo
    echo -e "${WHITE}Режим работы:${NC}"
    echo -e "  BOT_RUN_MODE: $(get_env_value BOT_RUN_MODE)"
    echo -e "  WEBHOOK_URL: $(get_env_value WEBHOOK_URL)"
    echo -e "  WEB_API_ENABLED: $(get_env_value WEB_API_ENABLED)"
    echo
    echo -e "${WHITE}Платежи:${NC}"
    echo -e "  Telegram Stars: $(get_env_value TELEGRAM_STARS_ENABLED)"
    echo -e "  YooKassa: $(get_env_value YOOKASSA_ENABLED)"
    echo -e "  CryptoBot: $(get_env_value CRYPTOBOT_ENABLED)"
    echo -e "  PayPalych: $(get_env_value PAL24_ENABLED)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

restart_bot() {
    echo -e "${CYAN}🔄 Перезапуск бота...${NC}"
    cd "$INSTALL_DIR"
    docker compose restart
    echo -e "${GREEN}✅ Бот перезапущен${NC}"
    docker compose ps
}

apply_ssl_certificates() {
    echo -e "${CYAN}🔒 Подключение SSL сертификатов к nginx панели${NC}"
    echo
    
    # Находим директорию панели
    local panel_dir=""
    if [ -d "/opt/remnawave" ]; then
        panel_dir="/opt/remnawave"
    elif [ -d "/root/remnawave" ]; then
        panel_dir="/root/remnawave"
    else
        echo -e "${RED}❌ Директория панели Remnawave не найдена${NC}"
        echo -e "${YELLOW}Эта функция работает только если панель установлена на этом сервере${NC}"
        return 1
    fi
    
    local panel_compose="$panel_dir/docker-compose.yml"
    
    if [ ! -f "$panel_compose" ]; then
        echo -e "${RED}❌ docker-compose.yml панели не найден: $panel_compose${NC}"
        return 1
    fi
    
    # Показываем доступные сертификаты
    echo -e "${WHITE}Доступные SSL сертификаты:${NC}"
    if [ -d "/etc/letsencrypt/live" ]; then
        ls -1 /etc/letsencrypt/live/ 2>/dev/null | grep -v "README" | while read domain; do
            echo -e "  ${GREEN}✓${NC} $domain"
        done
    else
        echo -e "${YELLOW}  Сертификаты не найдены в /etc/letsencrypt/live/${NC}"
        echo
        echo -e "${WHITE}Для получения сертификата выполните:${NC}"
        echo -e "${CYAN}  docker stop remnawave-nginx${NC}"
        echo -e "${CYAN}  certbot certonly --standalone -d yourdomain.com${NC}"
        echo -e "${CYAN}  docker start remnawave-nginx${NC}"
        return 1
    fi
    echo
    
    read -p "Введите домен для подключения (или Enter для всех): " DOMAIN
    
    # Создаём бэкап
    cp "$panel_compose" "$panel_compose.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Проверяем, не смонтирована ли уже папка /etc/letsencrypt
    if grep -q "/etc/letsencrypt:/etc/letsencrypt" "$panel_compose"; then
        echo -e "${GREEN}✅ Папка /etc/letsencrypt уже смонтирована в docker-compose панели${NC}"
    else
        echo -e "${CYAN}Добавляем монтирование /etc/letsencrypt в docker-compose панели...${NC}"
        
        # Ищем последнюю строку с .pem:ro или volumes в секции remnawave-nginx
        local last_pem_line=$(grep -n "\.pem:ro" "$panel_compose" | tail -1 | cut -d: -f1)
        
        if [ -z "$last_pem_line" ]; then
            # Пробуем найти volumes в remnawave-nginx
            local nginx_start=$(grep -n "remnawave-nginx:" "$panel_compose" | head -1 | cut -d: -f1)
            local network_line=$(tail -n +${nginx_start:-1} "$panel_compose" | grep -n "network_mode:" | head -1 | cut -d: -f1)
            
            if [ -n "$nginx_start" ] && [ -n "$network_line" ]; then
                last_pem_line=$((nginx_start + network_line - 2))
            else
                echo -e "${RED}❌ Не удалось найти место для вставки в docker-compose.yml${NC}"
                return 1
            fi
        fi
        
        # Добавляем монтирование
        local new_line="      - /etc/letsencrypt:/etc/letsencrypt:ro"
        head -n "$last_pem_line" "$panel_compose" > "$panel_compose.tmp"
        echo "$new_line" >> "$panel_compose.tmp"
        tail -n +$((last_pem_line + 1)) "$panel_compose" >> "$panel_compose.tmp"
        mv "$panel_compose.tmp" "$panel_compose"
        
        if grep -q "/etc/letsencrypt:/etc/letsencrypt" "$panel_compose"; then
            echo -e "${GREEN}✅ Монтирование добавлено${NC}"
        else
            echo -e "${RED}❌ Не удалось добавить монтирование${NC}"
            return 1
        fi
    fi
    
    # Перезапускаем nginx с пересозданием контейнера
    echo -e "${CYAN}Перезапуск nginx панели...${NC}"
    cd "$panel_dir"
    docker compose up -d --force-recreate remnawave-nginx 2>/dev/null || \
    docker compose restart remnawave-nginx 2>/dev/null || \
    docker restart remnawave-nginx 2>/dev/null
    
    sleep 3
    
    # Проверяем доступность
    local check_domain="${DOMAIN:-$(ls -1 /etc/letsencrypt/live/ 2>/dev/null | grep -v README | head -1)}"
    if [ -n "$check_domain" ] && docker exec remnawave-nginx test -f "/etc/letsencrypt/live/$check_domain/fullchain.pem" 2>/dev/null; then
        echo -e "${GREEN}✅ SSL сертификаты успешно подключены к nginx панели!${NC}"
    else
        echo -e "${YELLOW}⚠️ Проверьте логи: docker logs remnawave-nginx${NC}"
    fi
}

diagnose_network() {
    echo -e "${CYAN}🔍 Диагностика сети Docker${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Проверяем контейнер бота
    echo -e "\n${WHITE}1. Статус контейнера бота:${NC}"
    if docker ps --format '{{.Names}}' | grep -q "remnawave_bot"; then
        echo -e "   ${GREEN}✓${NC} remnawave_bot запущен"
    else
        echo -e "   ${RED}✗${NC} remnawave_bot НЕ запущен"
        return 1
    fi
    
    # Проверяем контейнер панели
    echo -e "\n${WHITE}2. Статус контейнера панели:${NC}"
    if docker ps --format '{{.Names}}' | grep -q "^remnawave$"; then
        echo -e "   ${GREEN}✓${NC} remnawave запущен"
    else
        echo -e "   ${RED}✗${NC} remnawave НЕ запущен (или имеет другое имя)"
        echo -e "   ${YELLOW}   Контейнеры:${NC}"
        docker ps --format "   - {{.Names}}" | grep -i remn || echo "   Не найдены"
    fi
    
    # Сети бота
    echo -e "\n${WHITE}3. Сети контейнера бота:${NC}"
    docker inspect remnawave_bot --format '{{range $net, $config := .NetworkSettings.Networks}}   - {{$net}} ({{$config.IPAddress}}){{"\n"}}{{end}}' 2>/dev/null || echo "   Ошибка"
    
    # Сети панели
    echo -e "\n${WHITE}4. Сети контейнера панели:${NC}"
    local panel_network=$(docker inspect remnawave --format '{{range $net, $config := .NetworkSettings.Networks}}{{$net}}{{"\n"}}{{end}}' 2>/dev/null | grep -v "^$" | head -1)
    if [ -n "$panel_network" ]; then
        echo -e "   ${GREEN}✓${NC} Сеть панели: $panel_network"
    else
        echo -e "   ${RED}✗${NC} Не удалось определить сеть панели"
    fi
    
    # Проверяем DNS
    echo -e "\n${WHITE}5. Проверка DNS (remnawave):${NC}"
    if docker exec remnawave_bot getent hosts remnawave >/dev/null 2>&1; then
        local ip=$(docker exec remnawave_bot getent hosts remnawave 2>/dev/null | awk '{print $1}')
        echo -e "   ${GREEN}✓${NC} remnawave -> $ip"
    else
        echo -e "   ${RED}✗${NC} DNS remnawave НЕ НАЙДЕН!"
    fi
    
    echo -e "\n${WHITE}6. Предложение по исправлению:${NC}"
    
    if [ -n "$panel_network" ]; then
        # Проверяем подключен ли бот к этой сети
        local bot_nets=$(docker inspect remnawave_bot --format '{{range $net, $_ := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null)
        
        if echo "$bot_nets" | grep -q "$panel_network"; then
            echo -e "   ${GREEN}Бот уже подключен к сети панели ($panel_network)${NC}"
        else
            echo -e "   ${YELLOW}Бот НЕ подключен к сети панели!${NC}"
            echo
            read -p "   Подключить контейнеры бота к сети $panel_network? [Y/n]: " fix_choice
            if [[ "${fix_choice,,}" != "n" ]]; then
                echo -e "${CYAN}Подключаем контейнеры...${NC}"
                
                docker network connect "$panel_network" remnawave_bot 2>/dev/null && \
                    echo -e "   ${GREEN}✓${NC} remnawave_bot подключен" || \
                    echo -e "   ${YELLOW}⚠${NC} remnawave_bot уже подключен или ошибка"
                    
                docker network connect "$panel_network" remnawave_bot_db 2>/dev/null && \
                    echo -e "   ${GREEN}✓${NC} remnawave_bot_db подключен" || \
                    echo -e "   ${YELLOW}⚠${NC} remnawave_bot_db уже подключен или ошибка"
                    
                docker network connect "$panel_network" remnawave_bot_redis 2>/dev/null && \
                    echo -e "   ${GREEN}✓${NC} remnawave_bot_redis подключен" || \
                    echo -e "   ${YELLOW}⚠${NC} remnawave_bot_redis уже подключен или ошибка"
                
                # Проверяем результат
                sleep 2
                echo
                if docker exec remnawave_bot getent hosts remnawave >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ Сеть настроена! DNS remnawave теперь доступен.${NC}"
                    echo -e "${YELLOW}   Перезапустите бота: ./configure.sh -> 8${NC}"
                else
                    echo -e "${RED}❌ DNS всё ещё недоступен. Проверьте имя контейнера панели.${NC}"
                fi
            fi
        fi
    else
        echo -e "   ${RED}Не удалось определить сеть панели автоматически${NC}"
        echo -e "   ${YELLOW}Выполните вручную:${NC}"
        echo -e "   ${WHITE}docker network ls${NC}"
        echo -e "   ${WHITE}docker network connect <СЕТЬ_ПАНЕЛИ> remnawave_bot${NC}"
    fi
}

# Проверка установки
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Файл .env не найден в $INSTALL_DIR${NC}"
    echo -e "${YELLOW}Сначала выполните установку бота.${NC}"
    exit 1
fi

# Главный цикл
while true; do
    print_menu
    read -p "Ваш выбор: " CHOICE
    
    case $CHOICE in
        1) edit_bot_token ;;
        2) edit_admin_ids ;;
        3) edit_remnawave ;;
        4) edit_payments ;;
        5) edit_notifications ;;
        6) edit_webhook ;;
        7) show_config ;;
        8) restart_bot ;;
        9) apply_ssl_certificates ;;
        10) diagnose_network ;;
        0) 
            echo -e "${GREEN}До свидания!${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}Неверный выбор${NC}"
            ;;
    esac
    
    echo
    read -p "Нажмите Enter для продолжения..."
done
