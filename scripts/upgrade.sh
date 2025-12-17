#!/bin/bash

# ===============================================
# 🔄 REMNAWAVE BEDOLAGA BOT - ОБНОВЛЕНИЕ
# ===============================================
# НЕ используем set -e чтобы продолжить при ошибках

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════
# ФУНКЦИИ (определяем ДО использования)
# ═══════════════════════════════════════════════════════════════

# Автоопределение директории установки
find_install_dir() {
    if [ -d "/opt/remnawave-bedolaga-telegram-bot" ]; then
        echo "/opt/remnawave-bedolaga-telegram-bot"
    elif [ -d "/root/remnawave-bedolaga-telegram-bot" ]; then
        echo "/root/remnawave-bedolaga-telegram-bot"
    elif [ -f "./docker-compose.yml" ] && [ -f "./.env" ]; then
        pwd
    else
        echo ""
    fi
}

# Функция обновления бота
upgrade_bot() {
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}📦 ОБНОВЛЕНИЕ БОТА${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    cd "$INSTALL_DIR"
    
    # Создание бэкапа
    echo -e "${CYAN}💾 Создание бэкапа...${NC}"
    BACKUP_DIR="$INSTALL_DIR/data/backups"
    mkdir -p "$BACKUP_DIR"
    cp .env "$BACKUP_DIR/.env_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    
    # Текущая версия
    CURRENT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    echo -e "${WHITE}Текущая версия:${NC} $CURRENT_COMMIT"
    
    # Обновление кода
    echo -e "${CYAN}📥 Получение обновлений...${NC}"
    git fetch origin main
    git reset --hard origin/main
    
    NEW_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    echo -e "${WHITE}Новая версия:${NC} $NEW_COMMIT"
    
    if [ "$CURRENT_COMMIT" = "$NEW_COMMIT" ]; then
        echo -e "${GREEN}✅ Уже актуальная версия${NC}"
    else
        echo -e "${GREEN}✅ Код обновлён: $CURRENT_COMMIT → $NEW_COMMIT${NC}"
    fi
    
    # Пересборка контейнеров
    echo -e "${CYAN}🐳 Пересборка контейнеров...${NC}"
    docker compose -f "$COMPOSE_FILE" down || true
    docker compose -f "$COMPOSE_FILE" build --no-cache
    
    if docker compose -f "$COMPOSE_FILE" up -d; then
        echo -e "${GREEN}✅ Бот обновлён и запущен${NC}"
    else
        echo -e "${RED}⚠️  Ошибка запуска контейнеров!${NC}"
        echo -e "${YELLOW}Проверьте: docker compose -f $COMPOSE_FILE logs${NC}"
        echo -e "${YELLOW}Возможно нужно создать сеть: docker network create remnawave-network${NC}"
    fi
}

# Функция установки команды bot
install_bot_command() {
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}🎮 УСТАНОВКА КОМАНДЫ 'bot'${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    if [ -f "/usr/local/bin/bot" ]; then
        echo -e "${YELLOW}Команда 'bot' уже существует. Обновить? (y/n) [y]:${NC}"
        read -n 1 -r REPLY < /dev/tty
        echo
        REPLY=${REPLY:-y}
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Пропущено${NC}"
            return
        fi
    fi
    
    echo -e "${CYAN}📝 Создание команды 'bot'...${NC}"
    
    # Создаём скрипт bot
    cat > /usr/local/bin/bot << BOTEOF
#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# 🤖 REMNAWAVE BEDOLAGA BOT - КОМАНДА УПРАВЛЕНИЯ
# ═══════════════════════════════════════════════════════════════

INSTALL_DIR="$INSTALL_DIR"
COMPOSE_FILE="$COMPOSE_FILE"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

check_install_dir() {
    if [ ! -d "\$INSTALL_DIR" ]; then
        echo -e "\${RED}❌ Директория бота не найдена: \$INSTALL_DIR\${NC}"
        exit 1
    fi
    cd "\$INSTALL_DIR"
}

do_logs() {
    check_install_dir
    echo -e "\${CYAN}📋 Логи бота (Ctrl+C для выхода)...\${NC}"
    docker compose -f "\$COMPOSE_FILE" logs -f --tail=150 bot
}

do_status() {
    check_install_dir
    echo -e "\${CYAN}═══════════════════════════════════════════════════════════════\${NC}"
    echo -e "\${WHITE}📊 СТАТУС КОНТЕЙНЕРОВ\${NC}"
    echo -e "\${CYAN}═══════════════════════════════════════════════════════════════\${NC}"
    echo
    docker compose -f "\$COMPOSE_FILE" ps
    echo
    echo -e "\${WHITE}📈 Использование ресурсов:\${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | grep -E "remnawave|postgres|redis" || echo "Контейнеры не запущены"
}

do_restart() {
    check_install_dir
    echo -e "\${CYAN}🔄 Перезапуск бота...\${NC}"
    docker compose -f "\$COMPOSE_FILE" restart
    echo -e "\${GREEN}✅ Бот перезапущен\${NC}"
}

do_start() {
    check_install_dir
    echo -e "\${CYAN}▶️  Запуск бота...\${NC}"
    docker compose -f "\$COMPOSE_FILE" up -d
    echo -e "\${GREEN}✅ Бот запущен\${NC}"
}

do_stop() {
    check_install_dir
    echo -e "\${CYAN}⏹️  Остановка бота...\${NC}"
    docker compose -f "\$COMPOSE_FILE" down
    echo -e "\${GREEN}✅ Бот остановлен\${NC}"
}

do_update() {
    check_install_dir
    echo -e "\${CYAN}📦 Обновление бота...\${NC}"
    cp .env ".env.backup_\$(date +%Y%m%d_%H%M%S)" 2>/dev/null
    git pull origin main
    docker compose -f "\$COMPOSE_FILE" down
    docker compose -f "\$COMPOSE_FILE" build --no-cache
    docker compose -f "\$COMPOSE_FILE" up -d
    echo -e "\${GREEN}✅ Обновление завершено\${NC}"
}

do_backup() {
    check_install_dir
    local BACKUP_DIR="\$INSTALL_DIR/data/backups"
    local TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
    mkdir -p "\$BACKUP_DIR"
    
    echo -e "\${CYAN}💾 Создание резервной копии...\${NC}"
    docker compose -f "\$COMPOSE_FILE" exec -T postgres pg_dump -U remnawave_user remnawave_bot > "\$BACKUP_DIR/db_\$TIMESTAMP.sql" 2>/dev/null
    cp .env "\$BACKUP_DIR/.env_\$TIMESTAMP"
    echo -e "\${GREEN}✅ Бэкап создан: \$BACKUP_DIR\${NC}"
}

do_health() {
    check_install_dir
    echo -e "\${CYAN}╔══════════════════════════════════════════════════════════════╗\${NC}"
    echo -e "\${CYAN}║           🏥 ДИАГНОСТИКА СИСТЕМЫ 🏥                          ║\${NC}"
    echo -e "\${CYAN}╚══════════════════════════════════════════════════════════════╝\${NC}"
    echo
    
    echo -e "\${WHITE}🐳 Контейнеры:\${NC}"
    docker compose -f "\$COMPOSE_FILE" ps
    echo
    
    echo -e "\${WHITE}📊 Сервисы:\${NC}"
    docker ps --format '{{.Names}}' | grep -q "remnawave_bot" && echo -e "  \${GREEN}✅ Bot: работает\${NC}" || echo -e "  \${RED}❌ Bot: не запущен\${NC}"
    docker compose -f "\$COMPOSE_FILE" exec -T postgres pg_isready -U remnawave_user >/dev/null 2>&1 && echo -e "  \${GREEN}✅ PostgreSQL: работает\${NC}" || echo -e "  \${RED}❌ PostgreSQL: не отвечает\${NC}"
    docker compose -f "\$COMPOSE_FILE" exec -T redis redis-cli ping >/dev/null 2>&1 && echo -e "  \${GREEN}✅ Redis: работает\${NC}" || echo -e "  \${RED}❌ Redis: не отвечает\${NC}"
    
    echo
    echo -e "\${WHITE}📋 Последние логи:\${NC}"
    docker compose -f "\$COMPOSE_FILE" logs --tail=10 bot 2>/dev/null
}

do_config() {
    check_install_dir
    \${EDITOR:-nano} "\$INSTALL_DIR/.env"
    echo -e "\${YELLOW}Перезапустите бота для применения: bot restart\${NC}"
}

show_menu() {
    clear
    echo -e "\${PURPLE}╔══════════════════════════════════════════════════════════════╗\${NC}"
    echo -e "\${PURPLE}║        🤖 REMNAWAVE BEDOLAGA BOT — УПРАВЛЕНИЕ 🤖             ║\${NC}"
    echo -e "\${PURPLE}╚══════════════════════════════════════════════════════════════╝\${NC}"
    echo
    echo -e "\${WHITE}Директория:\${NC} \${CYAN}\$INSTALL_DIR\${NC}"
    echo
    
    if docker ps --format '{{.Names}}' | grep -q "remnawave_bot"; then
        echo -e "\${WHITE}Статус:\${NC} \${GREEN}● Бот работает\${NC}"
    else
        echo -e "\${WHITE}Статус:\${NC} \${RED}○ Бот остановлен\${NC}"
    fi
    echo
    
    echo -e "\${WHITE}═══════════════════════════════════════════════════════════════\${NC}"
    echo
    echo -e "  \${CYAN}1)\${NC} 📋 Логи              \${CYAN}6)\${NC} 💾 Создать бэкап"
    echo -e "  \${CYAN}2)\${NC} 📊 Статус            \${CYAN}7)\${NC} 🏥 Диагностика"
    echo -e "  \${CYAN}3)\${NC} 🔄 Перезапуск        \${CYAN}8)\${NC} ⚙️  Редактировать .env"
    echo -e "  \${CYAN}4)\${NC} ▶️  Запуск            \${CYAN}9)\${NC} 📦 Обновить бота"
    echo -e "  \${CYAN}5)\${NC} ⏹️  Остановка         \${CYAN}q)\${NC} Выход"
    echo
}

interactive_menu() {
    while true; do
        show_menu
        read -p "Ваш выбор: " choice
        
        case \$choice in
            1) do_logs ;;
            2) do_status; read -p "Нажмите Enter..." ;;
            3) do_restart; read -p "Нажмите Enter..." ;;
            4) do_start; read -p "Нажмите Enter..." ;;
            5) do_stop; read -p "Нажмите Enter..." ;;
            6) do_backup; read -p "Нажмите Enter..." ;;
            7) do_health; read -p "Нажмите Enter..." ;;
            8) do_config ;;
            9) do_update; read -p "Нажмите Enter..." ;;
            q|Q|exit) echo -e "\${GREEN}До свидания!\${NC}"; exit 0 ;;
            *) echo -e "\${RED}Неверный выбор\${NC}"; sleep 1 ;;
        esac
    done
}

show_help() {
    echo -e "\${PURPLE}╔══════════════════════════════════════════════════════════════╗\${NC}"
    echo -e "\${PURPLE}║        🤖 REMNAWAVE BEDOLAGA BOT — СПРАВКА 🤖                ║\${NC}"
    echo -e "\${PURPLE}╚══════════════════════════════════════════════════════════════╝\${NC}"
    echo
    echo -e "\${WHITE}Использование:\${NC}"
    echo -e "  \${CYAN}bot\${NC}              — Интерактивное меню"
    echo -e "  \${CYAN}bot <команда>\${NC}   — Выполнить команду"
    echo
    echo -e "\${WHITE}Команды:\${NC}"
    echo -e "  \${GREEN}logs\${NC}       — Просмотр логов"
    echo -e "  \${GREEN}status\${NC}     — Статус контейнеров"
    echo -e "  \${GREEN}restart\${NC}    — Перезапуск"
    echo -e "  \${GREEN}start\${NC}      — Запуск"
    echo -e "  \${GREEN}stop\${NC}       — Остановка"
    echo -e "  \${GREEN}update\${NC}     — Обновление бота"
    echo -e "  \${GREEN}backup\${NC}     — Резервная копия"
    echo -e "  \${GREEN}health\${NC}     — Диагностика"
    echo -e "  \${GREEN}config\${NC}     — Редактировать .env"
}

case "\$1" in
    logs)       do_logs ;;
    status)     do_status ;;
    restart)    do_restart ;;
    start)      do_start ;;
    stop)       do_stop ;;
    update|upgrade) do_update ;;
    backup)     do_backup ;;
    health|check) do_health ;;
    config|edit) do_config ;;
    help|--help|-h) show_help ;;
    "")         interactive_menu ;;
    *)
        echo -e "\${RED}❌ Неизвестная команда: \$1\${NC}"
        echo "Используйте: bot help"
        exit 1
        ;;
esac
BOTEOF

    chmod +x /usr/local/bin/bot
    
    echo -e "${GREEN}✅ Команда 'bot' установлена!${NC}"
    echo
    echo -e "${WHITE}Теперь доступно:${NC}"
    echo -e "  ${CYAN}bot${NC}        — интерактивное меню"
    echo -e "  ${CYAN}bot help${NC}   — справка"
}

# Функция обновления скриптов установщика
update_installer() {
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}🔧 ОБНОВЛЕНИЕ СКРИПТОВ УСТАНОВЩИКА${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    INSTALLER_DIR="$INSTALL_DIR/.installer"
    
    echo -e "${CYAN}📥 Скачивание скриптов установщика...${NC}"
    
    TEMP_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/wrx861/bedolaga_auto_install.git "$TEMP_DIR" 2>/dev/null
    
    if [ -d "$TEMP_DIR/scripts" ]; then
        rm -rf "$INSTALLER_DIR" 2>/dev/null
        cp -r "$TEMP_DIR/scripts" "$INSTALLER_DIR"
        chmod +x "$INSTALLER_DIR"/*.sh 2>/dev/null
        chmod +x "$INSTALLER_DIR"/lib/*.sh 2>/dev/null
        
        VERSION=$(cat "$INSTALLER_DIR/VERSION" 2>/dev/null || echo "?")
        echo -e "${GREEN}✅ Скрипты установщика обновлены (v$VERSION)${NC}"
    else
        echo -e "${RED}❌ Ошибка загрузки${NC}"
    fi
    
    rm -rf "$TEMP_DIR"
}

# ═══════════════════════════════════════════════════════════════
# ОСНОВНОЙ КОД
# ═══════════════════════════════════════════════════════════════

INSTALL_DIR=$(find_install_dir)

if [ -z "$INSTALL_DIR" ]; then
    echo -e "${RED}❌ Директория бота не найдена!${NC}"
    echo -e "${YELLOW}Проверьте /opt/remnawave-bedolaga-telegram-bot${NC}"
    exit 1
fi

# Определяем compose файл
COMPOSE_FILE="docker-compose.yml"
if [ -f "$INSTALL_DIR/docker-compose.local.yml" ]; then
    COMPOSE_FILE="docker-compose.local.yml"
elif [ -f "$INSTALL_DIR/.install_config" ]; then
    source "$INSTALL_DIR/.install_config" 2>/dev/null
fi

# Проверяем наличие external network в compose файле
if grep -q "external: true" "$INSTALL_DIR/$COMPOSE_FILE" 2>/dev/null; then
    NETWORK_NAME=$(grep -A1 "external: true" "$INSTALL_DIR/$COMPOSE_FILE" | grep "name:" | awk '{print $2}' || echo "remnawave-network")
    if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
        echo -e "${YELLOW}⚠️  Обнаружена external network: $NETWORK_NAME${NC}"
        echo -e "${YELLOW}   Сеть не найдена. Создаём...${NC}"
        docker network create "$NETWORK_NAME" 2>/dev/null || true
    fi
fi

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🔄 REMNAWAVE BEDOLAGA BOT - ОБНОВЛЕНИЕ 🔄               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${WHITE}📁 Директория:${NC} ${CYAN}$INSTALL_DIR${NC}"
echo

# Проверка наличия команды bot
if [ -f "/usr/local/bin/bot" ]; then
    echo -e "${GREEN}✅ Команда 'bot' установлена${NC}"
else
    echo -e "${YELLOW}⚠️  Команда 'bot' не найдена${NC}"
fi

# Главное меню
echo
echo -e "${WHITE}Что вы хотите сделать?${NC}"
echo
echo -e "  ${CYAN}1)${NC} 📦 Обновить бота (git pull + rebuild)"
echo -e "  ${CYAN}2)${NC} 🎮 Установить команду 'bot'"
echo -e "  ${CYAN}3)${NC} 🔧 Обновить скрипты установщика"
echo -e "  ${CYAN}4)${NC} 📋 Всё вместе (рекомендуется)"
echo -e "  ${CYAN}0)${NC} Отмена"
echo
read -p "Ваш выбор [4]: " CHOICE < /dev/tty
CHOICE=${CHOICE:-4}

case $CHOICE in
    1)
        upgrade_bot
        ;;
    2)
        install_bot_command
        ;;
    3)
        update_installer
        ;;
    4)
        upgrade_bot
        install_bot_command
        update_installer
        ;;
    0)
        echo -e "${YELLOW}Отменено${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Неверный выбор${NC}"
        exit 1
        ;;
esac

# Финальное сообщение
echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ ОБНОВЛЕНИЕ ЗАВЕРШЕНО!                                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${WHITE}Используйте команду ${CYAN}bot${NC} для управления ботом${NC}"
echo
