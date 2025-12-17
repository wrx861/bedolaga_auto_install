#!/bin/bash

# ===============================================
# 🏁 ФИНАЛЬНЫЕ ФУНКЦИИ
# ===============================================

# Создание скриптов управления
create_management_scripts() {
    print_step "Создание скриптов управления"
    
    cd "$INSTALL_DIR"
    
    # Определяем compose файл
    local compose_opt=""
    if [ -f "docker-compose.local.yml" ]; then
        compose_opt="-f docker-compose.local.yml"
    fi
    
    # logs.sh
    cat > logs.sh << EOF
#!/bin/bash
cd "$INSTALL_DIR"
docker compose $compose_opt logs -f --tail=150 bot
EOF
    chmod +x logs.sh
    
    # restart.sh
    cat > restart.sh << EOF
#!/bin/bash
cd "$INSTALL_DIR"
docker compose $compose_opt restart
echo "Сервисы перезапущены"
EOF
    chmod +x restart.sh
    
    # status.sh
    cat > status.sh << EOF
#!/bin/bash
cd "$INSTALL_DIR"
echo "=== Статус контейнеров ==="
docker compose $compose_opt ps
echo ""
echo "=== Использование ресурсов ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "remnawave_bot|postgres|redis"
EOF
    chmod +x status.sh
    
    # backup.sh
    cat > backup.sh << EOF
#!/bin/bash
cd "$INSTALL_DIR"
BACKUP_DIR="./backups"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
mkdir -p "\$BACKUP_DIR"

echo "Создание резервной копии..."
docker compose $compose_opt exec -T postgres pg_dump -U remnawave_user remnawave_bot > "\$BACKUP_DIR/db_\$TIMESTAMP.sql"
cp .env "\$BACKUP_DIR/.env_\$TIMESTAMP"
echo "Резервная копия создана: \$BACKUP_DIR/db_\$TIMESTAMP.sql"
EOF
    chmod +x backup.sh
    
    # update.sh
    cat > update.sh << EOF
#!/bin/bash
cd "$INSTALL_DIR"
echo "Обновление бота..."
git pull origin main
docker compose $compose_opt down
docker compose $compose_opt up -d --build
echo "Обновление завершено"
EOF
    chmod +x update.sh
    
    print_success "Скрипты управления созданы"
    print_info "Доступные скрипты:"
    echo -e "  ${CYAN}./logs.sh${NC}    - просмотр логов"
    echo -e "  ${CYAN}./restart.sh${NC} - перезапуск сервисов"
    echo -e "  ${CYAN}./status.sh${NC}  - статус контейнеров"
    echo -e "  ${CYAN}./backup.sh${NC}  - создание резервной копии"
    echo -e "  ${CYAN}./update.sh${NC}  - обновление бота"
}

# Вывод финальной информации
print_final_info() {
    print_step "Установка завершена!"
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           🎉 УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА! 🎉                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${WHITE}📁 Директория установки:${NC} ${CYAN}$INSTALL_DIR${NC}"
    echo ""
    
    echo -e "${WHITE}🔧 Полезные команды:${NC}"
    echo -e "  ${CYAN}cd $INSTALL_DIR${NC}"
    echo -e "  ${CYAN}./logs.sh${NC}     - просмотр логов бота"
    echo -e "  ${CYAN}./restart.sh${NC}  - перезапуск"
    echo -e "  ${CYAN}./status.sh${NC}   - статус контейнеров"
    echo -e "  ${CYAN}./backup.sh${NC}   - создание бэкапа"
    echo ""
    
    if [ -n "$WEBHOOK_DOMAIN" ]; then
        echo -e "${WHITE}🌐 Webhook:${NC} https://$WEBHOOK_DOMAIN"
    fi
    
    if [ -n "$MINIAPP_DOMAIN" ]; then
        echo -e "${WHITE}📱 Mini App:${NC} https://$MINIAPP_DOMAIN"
    fi
    
    echo ""
    echo -e "${WHITE}📝 Конфигурация:${NC} $INSTALL_DIR/.env"
    echo ""
    
    echo -e "${YELLOW}⚠️  Важно:${NC}"
    echo -e "  - Настройте бота в Telegram через @BotFather"
    if [ "$PANEL_INSTALLED_LOCALLY" != "true" ] && [ -n "$REMNAWAVE_SECRET_KEY" ]; then
        echo -e "  - Убедитесь что REMNAWAVE_SECRET_KEY совпадает с панелью eGames"
    fi
    if [ "$KEEP_EXISTING_VOLUMES" = "true" ]; then
        echo -e "  - ${GREEN}Данные PostgreSQL сохранены, пароль закомментирован в .env${NC}"
    else
        echo -e "  - Сохраните пароль PostgreSQL из файла .env"
    fi
    echo ""
}

# Показ логов
ask_show_logs() {
    echo
    if confirm "Показать логи бота?"; then
        print_info "Показываем последние 150 строк логов (Ctrl+C для выхода)..."
        sleep 2
        cd "$INSTALL_DIR"
        if [ -f "docker-compose.local.yml" ]; then
            docker compose -f docker-compose.local.yml logs --tail=150 -f bot
        else
            docker compose logs --tail=150 -f bot
        fi
    fi
}
