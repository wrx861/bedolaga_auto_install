#!/bin/bash

# ===============================================
# 📦 УСТАНОВКА ПАКЕТОВ И ЗАВИСИМОСТЕЙ
# ===============================================

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
    local packages=(curl wget git nano htop certbot python3-certbot-nginx make openssl ca-certificates gnupg lsb-release dnsutils)
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

# Настройка firewall (ОПЦИОНАЛЬНО)
setup_firewall() {
    print_step "Настройка Firewall (UFW)"
    
    echo -e "${WHITE}Настроить Firewall (UFW)?${NC}"
    echo -e "${YELLOW}   Если у вас уже настроен firewall с нужными портами,${NC}"
    echo -e "${YELLOW}   выберите 'n' чтобы пропустить этот шаг.${NC}"
    echo
    
    if ! confirm "Настроить Firewall?"; then
        print_info "Firewall пропущен. Убедитесь что порты 22, 80, 443 открыты."
        return 0
    fi
    
    # Проверяем установлен ли ufw
    if ! command -v ufw &> /dev/null; then
        print_info "Установка UFW..."
        apt-get install -y ufw
    fi
    
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
