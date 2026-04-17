#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

collect_common_answers() {
  reset_state
  section "Подготовка установки"

  INSTALL_MODE="$1"
  PROJECT_SLUG="$(slugify "${2:-bedolaga-stack}")"

  case "$INSTALL_MODE" in
    bot-only)
      BOT_INSTALL_DIR="$(choose_install_dir 'Куда поставить бота?' '/opt/remnawave-bedolaga-telegram-bot' '/root/remnawave-bedolaga-telegram-bot')"
      CABINET_INSTALL_DIR="${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}"
      ;;
    cabinet-only)
      BOT_INSTALL_DIR="${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}"
      CABINET_INSTALL_DIR="$(choose_install_dir 'Куда поставить кабину?' '/opt/bedolaga-cabinet' '/root/bedolaga-cabinet')"
      ;;
    bot+cabinet)
      BOT_INSTALL_DIR="$(choose_install_dir 'Куда поставить бота?' '/opt/remnawave-bedolaga-telegram-bot' '/root/remnawave-bedolaga-telegram-bot')"
      CABINET_INSTALL_DIR="$(choose_install_dir 'Куда поставить кабину?' '/opt/bedolaga-cabinet' '/root/bedolaga-cabinet')"
      ;;
    *)
      BOT_INSTALL_DIR="$(choose_install_dir 'Куда поставить бота?' '/opt/remnawave-bedolaga-telegram-bot' '/root/remnawave-bedolaga-telegram-bot')"
      CABINET_INSTALL_DIR="$(choose_install_dir 'Куда поставить кабину?' '/opt/bedolaga-cabinet' '/root/bedolaga-cabinet')"
      ;;
  esac

  PROXY_INSTALL_DIR="/opt/bedolaga-proxy"
  TZ_VALUE="Europe/Moscow"

  case "$INSTALL_MODE" in
    cabinet-only|bot+cabinet) PROXY_MODE="caddy" ;;
    bot-only) PROXY_MODE="none" ;;
    *) PROXY_MODE="caddy" ;;
  esac

  case "$INSTALL_MODE" in
    bot-only)
      BOT_LOCAL_PORT="$(preferred_or_free_tcp_port 8080 18080 18120 || printf '8080')"
      CABINET_LOCAL_PORT="${CABINET_LOCAL_PORT:-3020}"
      ;;
    cabinet-only)
      BOT_LOCAL_PORT="${BOT_LOCAL_PORT:-8080}"
      CABINET_LOCAL_PORT="$(preferred_or_free_tcp_port 3020 13020 13080 || printf '3020')"
      ;;
    bot+cabinet)
      BOT_LOCAL_PORT="$(preferred_or_free_tcp_port 8080 18080 18120 || printf '8080')"
      CABINET_LOCAL_PORT="$(preferred_or_free_tcp_port 3020 13020 13080 || printf '3020')"
      ;;
    *)
      BOT_LOCAL_PORT="$(preferred_or_free_tcp_port 8080 18080 18120 || printf '8080')"
      CABINET_LOCAL_PORT="$(preferred_or_free_tcp_port 3020 13020 13080 || printf '3020')"
      ;;
  esac

  if [[ "$INSTALL_MODE" =~ ^(bot-only|bot\+cabinet)$ ]] && [[ "$BOT_LOCAL_PORT" != "8080" ]]; then
    warn "Порт 8080 занят, для бота выбрал: $BOT_LOCAL_PORT"
  fi

  if [[ "$INSTALL_MODE" =~ ^(cabinet-only|bot\+cabinet)$ ]] && [[ "$CABINET_LOCAL_PORT" != "3020" ]]; then
    warn "Порт 3020 занят, для кабины выбрал: $CABINET_LOCAL_PORT"
  fi

  local detected_remnawave=""
  detected_remnawave="$(detect_existing_remnawave_root 2>/dev/null || true)"
  if [[ -n "$detected_remnawave" ]]; then
    HOST_MODE="coexist"
    NETWORK_POLICY="preserve-existing"
    warn "Нашёл существующий Remnawave: $detected_remnawave"
  else
    HOST_MODE="clean"
    NETWORK_POLICY="bootstrap-safe"
  fi

  print_card "Что будет использоваться" \
    "Режим: $INSTALL_MODE" \
    "Бот: $BOT_INSTALL_DIR" \
    "Кабина: $CABINET_INSTALL_DIR" \
    "Прокси: $PROXY_MODE" \
    "Сервер: $HOST_MODE"

  write_state_var INSTALL_MODE "$INSTALL_MODE"
  write_state_var PROJECT_SLUG "$PROJECT_SLUG"
  write_state_var BOT_INSTALL_DIR "$BOT_INSTALL_DIR"
  write_state_var CABINET_INSTALL_DIR "$CABINET_INSTALL_DIR"
  write_state_var PROXY_INSTALL_DIR "$PROXY_INSTALL_DIR"
  write_state_var TZ_VALUE "$TZ_VALUE"
  write_state_var PROXY_MODE "$PROXY_MODE"
  write_state_var BOT_LOCAL_PORT "$BOT_LOCAL_PORT"
  write_state_var CABINET_LOCAL_PORT "$CABINET_LOCAL_PORT"
  write_state_var HOST_MODE "$HOST_MODE"
  write_state_var NETWORK_POLICY "$NETWORK_POLICY"
  write_state_var EXISTING_REMNAWAVE_DIR "$detected_remnawave"
}

detect_local_remnawave_api_url() {
  if [[ -n "${EXISTING_REMNAWAVE_DIR:-}" ]]; then
    printf '%s\n' 'http://remnawave:3000'
    return 0
  fi

  if detect_existing_remnawave_root >/dev/null 2>&1; then
    printf '%s\n' 'http://remnawave:3000'
    return 0
  fi

  if command_exists docker; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -Eq '^(remnawave|remnawave-nginx|remnawave-backend|remnawave-frontend)$'; then
      printf '%s\n' 'http://remnawave:3000'
      return 0
    fi
  fi

  return 1
}

collect_bot_answers() {
  section "Настройка бота"
  print_note "Сейчас нужны только данные, без лишней технички."

  BOT_TOKEN_VALUE="$(prompt_secret 'Токен Telegram-бота')"
  ADMIN_IDS_VALUE="$(prompt 'Telegram ID админа/админов (через запятую)')"

  local remnawave_api_default=""
  local remnawave_connect_default="2"
  remnawave_api_default="$(detect_local_remnawave_api_url 2>/dev/null || true)"
  [[ -n "$remnawave_api_default" ]] && remnawave_connect_default="1"

  REMNAWAVE_SETUP_MODE="$(choose_option 'Подключить Remnawave сейчас?' "$remnawave_connect_default" 'да, подключить сейчас' 'нет, подключу позже')"

  if [[ "$REMNAWAVE_SETUP_MODE" == 'да, подключить сейчас' ]]; then
    REMNAWAVE_SETUP_MODE="now"
    if [[ -n "$remnawave_api_default" ]]; then
      ok "Нашёл локальную панель Remnawave"
      REMNAWAVE_API_URL_VALUE="$(prompt 'Адрес панели Remnawave' "$remnawave_api_default")"
    else
      REMNAWAVE_API_URL_VALUE="$(prompt 'Адрес панели Remnawave')"
    fi

    REMNAWAVE_AUTH_TYPE_VALUE="api_key"
    REMNAWAVE_API_KEY_VALUE="$(prompt_secret 'API-ключ Remnawave')"
  else
    REMNAWAVE_SETUP_MODE="later"
    REMNAWAVE_API_URL_VALUE=""
    REMNAWAVE_AUTH_TYPE_VALUE="api_key"
    REMNAWAVE_API_KEY_VALUE=""
    warn "Хорошо. Бота ставлю сейчас, панель подключишь позже."
  fi

  BOT_POSTGRES_PASSWORD="$(random_hex 24)"
  BOT_WEB_API_TOKEN="$(random_hex 24)"
  CABINET_JWT_SECRET_VALUE="$(random_hex 32)"

  print_card "Кратко по боту" \
    "Папка: $BOT_INSTALL_DIR" \
    "Локальный порт: $BOT_LOCAL_PORT" \
    "Remnawave: $REMNAWAVE_SETUP_MODE"

  write_state_var BOT_TOKEN_VALUE "$BOT_TOKEN_VALUE"
  write_state_var ADMIN_IDS_VALUE "$ADMIN_IDS_VALUE"
  write_state_var REMNAWAVE_SETUP_MODE "$REMNAWAVE_SETUP_MODE"
  write_state_var REMNAWAVE_API_URL_VALUE "$REMNAWAVE_API_URL_VALUE"
  write_state_var REMNAWAVE_AUTH_TYPE_VALUE "$REMNAWAVE_AUTH_TYPE_VALUE"
  write_state_var REMNAWAVE_API_KEY_VALUE "${REMNAWAVE_API_KEY_VALUE:-}"
  write_state_var REMNAWAVE_USERNAME_VALUE "${REMNAWAVE_USERNAME_VALUE:-}"
  write_state_var REMNAWAVE_PASSWORD_VALUE "${REMNAWAVE_PASSWORD_VALUE:-}"
  write_state_var REMNAWAVE_CADDY_TOKEN_VALUE "${REMNAWAVE_CADDY_TOKEN_VALUE:-}"
  write_state_var BOT_POSTGRES_PASSWORD "$BOT_POSTGRES_PASSWORD"
  write_state_var BOT_WEB_API_TOKEN "$BOT_WEB_API_TOKEN"
  write_state_var CABINET_JWT_SECRET_VALUE "$CABINET_JWT_SECRET_VALUE"
}

collect_cabinet_answers() {
  section "Настройка кабины"
  CABINET_DOMAIN_VALUE="$(prompt 'Домен кабины' 'cabinet.example.com')"
  VITE_TELEGRAM_BOT_USERNAME_VALUE="$(prompt 'Юзернейм Telegram-бота (без @)')"
  VITE_APP_NAME_VALUE="$(prompt 'Название кабинета' 'VPN Cabinet')"
  VITE_APP_LOGO_VALUE="$(prompt 'Текст логотипа' 'V')"

  print_card "Кратко по кабине" \
    "Папка: $CABINET_INSTALL_DIR" \
    "Домен: $CABINET_DOMAIN_VALUE" \
    "Локальный порт: $CABINET_LOCAL_PORT"

  write_state_var CABINET_DOMAIN_VALUE "$CABINET_DOMAIN_VALUE"
  write_state_var VITE_TELEGRAM_BOT_USERNAME_VALUE "$VITE_TELEGRAM_BOT_USERNAME_VALUE"
  write_state_var VITE_APP_NAME_VALUE "$VITE_APP_NAME_VALUE"
  write_state_var VITE_APP_LOGO_VALUE "$VITE_APP_LOGO_VALUE"
}
