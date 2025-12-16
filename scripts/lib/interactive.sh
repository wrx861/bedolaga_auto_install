#!/bin/bash

# ===============================================
# 🎮 ИНТЕРАКТИВНЫЙ ВВОД И НАСТРОЙКА
# ===============================================

# Выбор директории установки
select_install_dir() {
    print_step "Выбор директории установки"
    
    echo -e "${WHITE}Куда установить бота?${NC}"
    echo -e "  ${CYAN}1)${NC} /opt/remnawave-bedolaga-telegram-bot ${YELLOW}(рекомендуется)${NC}"
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
    print_step "Тип установки"
    
    echo -e "${WHITE}Где установлена панель Remnawave?${NC}"
    echo -e "  ${CYAN}1)${NC} На этом сервере ${YELLOW}(бот будет подключен к Docker сети панели)${NC}"
    echo -e "  ${CYAN}2)${NC} На другом сервере ${YELLOW}(бот будет подключаться по внешнему URL)${NC}"
    echo
    
    while true; do
        read -p "Ваш выбор (1-2): " panel_choice < /dev/tty
        case $panel_choice in
            1)
                PANEL_INSTALLED_LOCALLY="true"
                setup_local_panel
                break
                ;;
            2)
                PANEL_INSTALLED_LOCALLY="false"
                print_info "Бот будет установлен отдельно (standalone)."
                print_info "Укажите внешний URL панели при настройке."
                break
                ;;
            *)
                echo -e "${YELLOW}   Пожалуйста, введите 1 или 2${NC}"
                ;;
        esac
    done
}

# Настройка локальной панели
setup_local_panel() {
    # Поиск директории панели
    echo
    echo -e "${WHITE}Где установлена панель?${NC}"
    echo -e "  ${CYAN}1)${NC} /opt/remnawave ${YELLOW}(стандартный путь)${NC}"
    echo -e "  ${CYAN}2)${NC} /root/remnawave"
    echo -e "  ${CYAN}3)${NC} Указать свой путь"
    echo
    
    while true; do
        read -p "Ваш выбор (1-3): " panel_dir_choice < /dev/tty
        case $panel_dir_choice in
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
}

# Определение Docker сети панели
detect_panel_network() {
    print_info "Поиск Docker сети панели Remnawave..."
    
    # Способ 1: Найти сеть по запущенному контейнеру remnawave
    local container_network=$(docker inspect remnawave --format '{{range $net, $config := .NetworkSettings.Networks}}{{$net}}{{"\n"}}{{end}}' 2>/dev/null | grep -v "^$" | head -1)
    if [ -n "$container_network" ] && [ "$container_network" != "host" ] && [ "$container_network" != "none" ]; then
        REMNAWAVE_DOCKER_NETWORK="$container_network"
        print_success "Найдена Docker сеть: $REMNAWAVE_DOCKER_NETWORK"
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
    
    # Способ 3: Поиск сети содержащей "remnawave" в имени
    local found_network=$(docker network ls --format '{{.Name}}' | grep -i "remnawave" | grep -v "bedolaga" | grep -v "bot" | head -1)
    if [ -n "$found_network" ]; then
        REMNAWAVE_DOCKER_NETWORK="$found_network"
        print_success "Найдена Docker сеть: $REMNAWAVE_DOCKER_NETWORK"
        return
    fi
    
    # Не удалось найти - спросить пользователя
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
    fi
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
        
        # Убираем протокол
        result=$(echo "$result" | sed 's|^https\?://||' | sed 's|/$||')
        
        # Валидация формата
        if ! validate_domain "$result"; then
            print_error "Неверный формат домена: $result"
            echo -e "${YELLOW}   Домен должен быть вида: bot.example.com${NC}"
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
            echo -e "${YELLOW}   2) Продолжить с этим доменом${NC}"
            echo -e "${YELLOW}   3) Пропустить - Enter${NC}"
            echo
            read -p "   Выберите (1/2/3 или Enter): " choice < /dev/tty
            
            case $choice in
                1) continue ;;
                2) 
                    eval "$var_name='$result'"
                    return 0
                    ;;
                3|"")
                    eval "$var_name=''"
                    print_info "Пропущено."
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
        echo -e "${WHITE}   Нажмите Enter для рекомендуемого адреса${NC}"
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
    
    # Дополнительные параметры авторизации
    echo -e "\n${CYAN}5. Тип авторизации к панели${NC}"
    echo -e "  ${CYAN}[1]${NC} API Key (по умолчанию)"
    echo -e "  ${CYAN}[2]${NC} Basic Auth"
    echo
    read -p "   Выберите тип авторизации [1]: " auth_choice < /dev/tty
    auth_choice=${auth_choice:-1}
    
    REMNAWAVE_AUTH_TYPE="api_key"
    REMNAWAVE_USERNAME=""
    REMNAWAVE_PASSWORD=""
    
    if [ "$auth_choice" == "2" ]; then
        REMNAWAVE_AUTH_TYPE="basic_auth"
        read -p "   Введите имя пользователя (REMNAWAVE_USERNAME): " REMNAWAVE_USERNAME < /dev/tty
        read -s -p "   Введите пароль (REMNAWAVE_PASSWORD): " REMNAWAVE_PASSWORD < /dev/tty
        echo
        print_success "Basic Auth настроен"
    fi
    
    # Проверка на eGames SECRET_KEY
    # SECRET_KEY нужен ТОЛЬКО при обращении к панели через ВНЕШНИЙ URL (https://)
    # При локальном подключении (http://remnawave:3000) SECRET_KEY вызовет ошибку!
    
    if [[ "$REMNAWAVE_API_URL" == http://remnawave:* ]] || [[ "$REMNAWAVE_API_URL" == http://localhost:* ]] || [[ "$REMNAWAVE_API_URL" == http://127.0.0.1:* ]]; then
        # Локальное подключение - SECRET_KEY НЕ НУЖЕН
        USE_EGAMES="false"
        REMNAWAVE_SECRET_KEY=""
        print_info "Локальное подключение к панели - SECRET_KEY не требуется"
    else
        # Внешнее подключение - спрашиваем про eGames
        echo -e "\n${CYAN}6. Панель установлена через скрипт eGames?${NC}"
        echo -e "${YELLOW}   eGames добавляет защиту доступа к панели через параметр в URL${NC}"
        echo -e "${YELLOW}   (SECRET_KEY нужен только при подключении через внешний URL)${NC}"
        echo
        
        read -p "   Используете панель, установленную скриптом eGames? [y/N]: " use_egames_input < /dev/tty
        if [[ "${use_egames_input,,}" == "y" ]]; then
            USE_EGAMES="true"
            echo -e "\n${CYAN}   Введите секретный ключ в формате XXXXXXX=DDDDDDDD${NC}"
            echo -e "${WHITE}   Это параметр из URL доступа к панели.${NC}"
            echo
            echo -e "${YELLOW}   Пример URL: https://panel.example.com/auth/login?MHPsUKCz=VfHqrBwp${NC}"
            echo -e "${YELLOW}   SECRET_KEY: MHPsUKCz=VfHqrBwp${NC}"
            echo
            read -p "   REMNAWAVE_SECRET_KEY: " REMNAWAVE_SECRET_KEY < /dev/tty
            if [ -n "$REMNAWAVE_SECRET_KEY" ]; then
                print_success "eGames SECRET_KEY сохранён"
            else
                print_warning "SECRET_KEY не указан"
            fi
        else
            USE_EGAMES="false"
            REMNAWAVE_SECRET_KEY=""
        fi
    fi
    
    # Домен для webhook
    echo -e "\n${CYAN}7. Домен для webhook (опционально)${NC}"
    echo -e "${YELLOW}   Пример: bot.yourdomain.com${NC}"
    echo -e "${YELLOW}   Оставьте пустым для режима polling${NC}"
    input_domain "   WEBHOOK_DOMAIN: " WEBHOOK_DOMAIN
    
    # Домен для miniapp
    echo -e "\n${CYAN}8. Домен для Mini App (опционально)${NC}"
    echo -e "${YELLOW}   Пример: miniapp.yourdomain.com${NC}"
    input_domain "   MINIAPP_DOMAIN: " MINIAPP_DOMAIN
    
    # Настройки уведомлений
    echo -e "\n${CYAN}9. Chat ID для уведомлений (опционально)${NC}"
    echo -e "${YELLOW}   Формат: -1001234567890${NC}"
    read -p "   ADMIN_NOTIFICATIONS_CHAT_ID: " ADMIN_NOTIFICATIONS_CHAT_ID < /dev/tty
    
    # PostgreSQL пароль
    echo -e "\n${CYAN}10. Пароль для PostgreSQL${NC}"
    echo -e "${YELLOW}   Оставьте пустым для автогенерации${NC}"
    read -s -p "   POSTGRES_PASSWORD: " POSTGRES_PASSWORD < /dev/tty
    echo
    if [ -z "$POSTGRES_PASSWORD" ]; then
        POSTGRES_PASSWORD=$(generate_safe_password 24)
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
