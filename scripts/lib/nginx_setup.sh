#!/bin/bash

# ===============================================
# 🌐 NGINX НАСТРОЙКА И SSL
# ===============================================

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
    
    # Получение SSL сертификатов
    setup_ssl
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
    
    # Определяем пути к конфигам nginx
    local NGINX_AVAILABLE="/etc/nginx/sites-available"
    local NGINX_ENABLED="/etc/nginx/sites-enabled"
    
    # Проверяем существование директорий
    if [ ! -d "$NGINX_AVAILABLE" ]; then
        mkdir -p "$NGINX_AVAILABLE"
    fi
    if [ ! -d "$NGINX_ENABLED" ]; then
        mkdir -p "$NGINX_ENABLED"
    fi
    
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
        
        # Создаём символическую ссылку для активации
        if [ "$NGINX_AVAILABLE" != "$NGINX_ENABLED" ]; then
            ln -sf "$NGINX_AVAILABLE/bedolaga-webhook" "$NGINX_ENABLED/bedolaga-webhook"
        fi
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
    
    # Статические файлы Mini App
    root ${INSTALL_DIR}/miniapp;
    index index.html;
    
    # Основной location - отдаём статику напрямую
    location / {
        try_files \$uri \$uri/ /index.html;
        expires 1h;
        add_header Cache-Control "public";
    }
    
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
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # app-config.json с CORS проксируем на бота
    location = /app-config.json {
        add_header Access-Control-Allow-Origin "*";
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
        
        # Создаём символическую ссылку для активации
        if [ "$NGINX_AVAILABLE" != "$NGINX_ENABLED" ]; then
            ln -sf "$NGINX_AVAILABLE/bedolaga-miniapp" "$NGINX_ENABLED/bedolaga-miniapp"
        fi
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
            
            # Если использовали nginx панели - нужно добавить сертификаты и перезапустить
            if [ "$PANEL_NGINX_HOST_MODE" = "true" ]; then
                print_info "Добавление сертификатов в конфигурацию панели..."
                
                # Добавляем монтирование /etc/letsencrypt в docker-compose панели
                add_ssl_to_panel_compose
                
                # Перезапускаем nginx панели с пересозданием контейнера (для подхвата новых volumes)
                print_info "Перезапуск nginx панели для применения сертификатов..."
                cd "$REMNAWAVE_PANEL_DIR"
                docker compose up -d --force-recreate remnawave-nginx 2>/dev/null || \
                docker compose restart remnawave-nginx 2>/dev/null || \
                docker restart remnawave-nginx 2>/dev/null
                
                # Проверяем что сертификаты видны в контейнере
                sleep 3
                if docker exec remnawave-nginx test -f "/etc/letsencrypt/live/${WEBHOOK_DOMAIN:-$MINIAPP_DOMAIN}/fullchain.pem" 2>/dev/null; then
                    print_success "Сертификаты успешно подключены к nginx панели"
                else
                    print_warning "Сертификаты могут быть недоступны в контейнере nginx"
                    print_info "Попробуйте вручную: cd $REMNAWAVE_PANEL_DIR && docker compose up -d --force-recreate remnawave-nginx"
                fi
            fi
        else
            print_warning "SSL сертификаты не были получены"
            echo -e "${CYAN}   Вы можете получить их позже командой:${NC}"
            if [ "$PANEL_NGINX_HOST_MODE" = "true" ]; then
                echo -e "${CYAN}   1. docker stop remnawave-nginx${NC}"
                echo -e "${CYAN}   2. certbot certonly --standalone -d yourdomain.com${NC}"
                echo -e "${CYAN}   3. docker start remnawave-nginx${NC}"
                echo -e "${CYAN}   4. cd $REMNAWAVE_PANEL_DIR && docker compose up -d --force-recreate remnawave-nginx${NC}"
            else
                echo -e "${CYAN}   certbot --nginx -d yourdomain.com${NC}"
            fi
        fi
    else
        print_info "SSL сертификаты можно получить позже командой:"
        if [ "$PANEL_NGINX_HOST_MODE" = "true" ]; then
            echo -e "${CYAN}  1. docker stop remnawave-nginx${NC}"
            echo -e "${CYAN}  2. certbot certonly --standalone -d yourdomain.com${NC}"
            echo -e "${CYAN}  3. docker start remnawave-nginx${NC}"
            echo -e "${CYAN}  4. cd $REMNAWAVE_PANEL_DIR && docker compose up -d --force-recreate remnawave-nginx${NC}"
        else
            echo -e "${CYAN}  certbot --nginx -d yourdomain.com${NC}"
        fi
    fi
}

# Функция для ручного подключения SSL сертификатов к nginx панели
# Можно вызвать отдельно после получения сертификатов вручную
apply_ssl_to_panel_nginx() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        print_error "Укажите домен: apply_ssl_to_panel_nginx yourdomain.com"
        return 1
    fi
    
    # Проверяем существование сертификатов
    if [ ! -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        print_error "Сертификат для $domain не найден в /etc/letsencrypt/live/$domain/"
        return 1
    fi
    
    print_info "Подключение SSL сертификата для $domain..."
    
    # Находим директорию панели
    local panel_dir=""
    if [ -d "/opt/remnawave" ]; then
        panel_dir="/opt/remnawave"
    elif [ -d "/root/remnawave" ]; then
        panel_dir="/root/remnawave"
    else
        print_error "Директория панели Remnawave не найдена"
        return 1
    fi
    
    local panel_compose="$panel_dir/docker-compose.yml"
    
    if [ ! -f "$panel_compose" ]; then
        print_error "docker-compose.yml панели не найден: $panel_compose"
        return 1
    fi
    
    # Устанавливаем переменную для add_ssl_to_panel_compose
    REMNAWAVE_PANEL_DIR="$panel_dir"
    
    # Добавляем монтирование /etc/letsencrypt
    add_ssl_to_panel_compose
    
    # Перезапускаем nginx с пересозданием контейнера
    print_info "Перезапуск nginx панели..."
    cd "$panel_dir"
    docker compose up -d --force-recreate remnawave-nginx 2>/dev/null || \
    docker compose restart remnawave-nginx 2>/dev/null || \
    docker restart remnawave-nginx 2>/dev/null
    
    sleep 3
    
    # Проверяем доступность сертификата
    if docker exec remnawave-nginx test -f "/etc/letsencrypt/live/$domain/fullchain.pem" 2>/dev/null; then
        print_success "SSL сертификат для $domain успешно подключен!"
    else
        print_warning "Сертификат может быть недоступен. Проверьте логи: docker logs remnawave-nginx"
    fi
}

# Настройка firewall
