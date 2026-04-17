#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

resolve_bot_root() {
  load_state
  local candidate
  for candidate in \
    "${BOT_INSTALL_DIR:-}" \
    /opt/remnawave-bedolaga-telegram-bot \
    /opt/remnawave-bedolaga-telegram-bot-test \
    /root/remnawave-bedolaga-telegram-bot
  do
    [[ -n "$candidate" && -d "$candidate/.git" ]] && {
      printf '%s\n' "$candidate"
      return 0
    }
  done
  return 1
}

resolve_cabinet_root() {
  load_state
  local candidate
  for candidate in \
    "${CABINET_INSTALL_DIR:-}" \
    /opt/bedolaga-cabinet \
    /opt/bedolaga-cabinet-test \
    /root/bedolaga-cabinet
  do
    [[ -n "$candidate" && -d "$candidate/.git" ]] && {
      printf '%s\n' "$candidate"
      return 0
    }
  done
  return 1
}

ensure_bot_ready() {
  local bot_root
  bot_root="$(resolve_bot_root)" || { error "Репозиторий бота не найден"; return 1; }
  [[ -f "$bot_root/bundles/.env" ]] || { error "Не найден bot bundle env: $bot_root/bundles/.env"; return 1; }
  [[ -f "$bot_root/docker-compose.yml" ]] || { error "Не найден bot docker-compose.yml: $bot_root"; return 1; }
}

ensure_cabinet_ready() {
  local cabinet_root
  cabinet_root="$(resolve_cabinet_root)" || { error "Репозиторий кабины не найден"; return 1; }
  [[ -f "$cabinet_root/bundles/.env" ]] || { error "Не найден cabinet bundle env: $cabinet_root/bundles/.env"; return 1; }
  [[ -f "$cabinet_root/bundles/docker-compose.yml" ]] || { error "Не найден cabinet bundle compose: $cabinet_root/bundles/docker-compose.yml"; return 1; }
}

prepare_bot_runtime_dirs() {
  local bot_root="$1"
  mkdir -p "$bot_root/logs" "$bot_root/data" "$bot_root/data/backups" "$bot_root/uploads" "$bot_root/locales"
  if is_root; then
    chown -R 1000:1000 "$bot_root/logs" "$bot_root/data" "$bot_root/uploads" "$bot_root/locales"
  fi
  ok "Runtime-директории бота подготовлены"
}

normalize_bot_port_model() {
  local bot_root="$1"
  local env_file="$bot_root/.env"
  local compose_file="$bot_root/docker-compose.yml"
  local host_port="${BOT_LOCAL_PORT:-8080}"

  [[ -f "$env_file" ]] || return 1
  [[ -f "$compose_file" ]] || return 1

  python3 - "$env_file" "$host_port" <<'PY'
from pathlib import Path
import sys
env_path = Path(sys.argv[1])
host_port = sys.argv[2]
text = env_path.read_text(encoding='utf-8')
lines = text.splitlines()
out = []
seen = set()
for line in lines:
    if line.startswith('WEB_API_PORT='):
        out.append('WEB_API_PORT=8080')
        seen.add('WEB_API_PORT=')
    elif line.startswith('BOT_HOST_PORT='):
        out.append(f'BOT_HOST_PORT={host_port}')
        seen.add('BOT_HOST_PORT=')
    else:
        out.append(line)
if 'WEB_API_PORT=' not in seen:
    out.append('WEB_API_PORT=8080')
if 'BOT_HOST_PORT=' not in seen:
    out.append(f'BOT_HOST_PORT={host_port}')
env_path.write_text('\n'.join(out) + '\n', encoding='utf-8')
PY

  python3 - "$compose_file" <<'PY'
from pathlib import Path
import sys
compose_path = Path(sys.argv[1])
text = compose_path.read_text(encoding='utf-8')
old = "      - '${WEB_API_PORT:-8080}:8080'"
new = "      - '${BOT_HOST_PORT:-18080}:8080'"
if old in text:
    text = text.replace(old, new)
compose_path.write_text(text, encoding='utf-8')
PY

  ok "Портовая схема бота нормализована: container 8080 -> host ${host_port}"
}

install_bot_now() {
  load_state
  section "Установить бота сейчас"
  ensure_bot_ready || return 1
  local bot_root
  bot_root="$(resolve_bot_root)" || return 1

  cp "$bot_root/bundles/.env" "$bot_root/.env"
  ok "Файл .env для бота скопирован в $bot_root/.env"

  prepare_bot_runtime_dirs "$bot_root"
  normalize_bot_port_model "$bot_root"

  local compose_bin
  compose_bin="$(compose_cmd)" || return 1
  local cmd_str
  cmd_str="$compose_bin -f docker-compose.yml up -d"

  printf 'Будет выполнено в %s:\n  %s\n' "$bot_root" "$cmd_str"

  if confirm "Запустить deploy бота сейчас?"; then
    (
      cd "$bot_root"
      compose_run -f docker-compose.yml up -d
    )
    ok "Deploy бота завершён"
  else
    warn "Deploy бота пропущен"
  fi
}

install_cabinet_now() {
  load_state
  section "Установить кабину сейчас"
  ensure_cabinet_ready || return 1
  local cabinet_root
  cabinet_root="$(resolve_cabinet_root)" || return 1

  cp "$cabinet_root/bundles/.env" "$cabinet_root/.env"
  ok "Файл .env для кабины скопирован в $cabinet_root/.env"

  local compose_bin
  compose_bin="$(compose_cmd)" || return 1
  local cmd_str="$compose_bin -f $cabinet_root/bundles/docker-compose.yml up -d"
  printf 'Будет выполнено в %s:\n  %s\n' "$cabinet_root" "$cmd_str"

  if confirm "Запустить deploy кабины сейчас?"; then
    (cd "$cabinet_root" && compose_run -f "$cabinet_root/bundles/docker-compose.yml" up -d)
    ok "Deploy кабины завершён"
  else
    warn "Deploy кабины пропущен"
  fi
}

install_remnawave_panel_now() {
  load_state
  section "Установить панель Remnawave"

  local panel_root="${REMNAWAVE_PANEL_INSTALL_DIR:-/opt/remnawave}"
  local panel_domain="${REMNAWAVE_PANEL_DOMAIN_VALUE:-}"
  local sub_public_domain="${REMNAWAVE_SUB_PUBLIC_DOMAIN_VALUE:-}"
  local proxy_mode="${REMNAWAVE_PROXY_MODE_VALUE:-caddy}"
  local compose_url="https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/docker-compose-prod.yml"
  local env_url="https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/.env.sample"

  [[ -n "$panel_domain" ]] || { error "Не указан домен панели Remnawave"; return 1; }
  [[ -n "$sub_public_domain" ]] || { error "Не указан публичный адрес подписок"; return 1; }

  mkdir -p "$panel_root"
  curl -fsSL "$compose_url" -o "$panel_root/docker-compose.yml"
  curl -fsSL "$env_url" -o "$panel_root/.env"
  ok "Официальные файлы Remnawave скачаны"

  sed -i "s/^JWT_AUTH_SECRET=.*/JWT_AUTH_SECRET=$(openssl rand -hex 64)/" "$panel_root/.env"
  sed -i "s/^JWT_API_TOKENS_SECRET=.*/JWT_API_TOKENS_SECRET=$(openssl rand -hex 64)/" "$panel_root/.env"
  sed -i "s/^METRICS_PASS=.*/METRICS_PASS=$(openssl rand -hex 64)/" "$panel_root/.env"
  sed -i "s/^WEBHOOK_SECRET_HEADER=.*/WEBHOOK_SECRET_HEADER=$(openssl rand -hex 64)/" "$panel_root/.env"

  local pg_pw
  pg_pw="$(openssl rand -hex 24)"
  sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$pg_pw/" "$panel_root/.env"
  sed -i "s|^\(DATABASE_URL=\"postgresql://postgres:\)[^@]*\(@.*\)|\1$pg_pw\2|" "$panel_root/.env"

  if grep -q '^FRONT_END_DOMAIN=' "$panel_root/.env"; then
    sed -i "s|^FRONT_END_DOMAIN=.*|FRONT_END_DOMAIN=$panel_domain|" "$panel_root/.env"
  else
    printf '\nFRONT_END_DOMAIN=%s\n' "$panel_domain" >> "$panel_root/.env"
  fi

  if grep -q '^SUB_PUBLIC_DOMAIN=' "$panel_root/.env"; then
    sed -i "s|^SUB_PUBLIC_DOMAIN=.*|SUB_PUBLIC_DOMAIN=$sub_public_domain|" "$panel_root/.env"
  else
    printf 'SUB_PUBLIC_DOMAIN=%s\n' "$sub_public_domain" >> "$panel_root/.env"
  fi

  if grep -q '^PANEL_DOMAIN=' "$panel_root/.env"; then
    sed -i "s|^PANEL_DOMAIN=.*|PANEL_DOMAIN=$panel_domain|" "$panel_root/.env"
  else
    printf 'PANEL_DOMAIN=%s\n' "$panel_domain" >> "$panel_root/.env"
  fi

  printf 'Будет выполнено в %s:\n  %s\n' "$panel_root" "docker compose up -d"
  if ! confirm "Запустить установку панели Remnawave сейчас?"; then
    warn "Установка панели пропущена"
    return 0
  fi

  (cd "$panel_root" && compose_run up -d)
  ok "Панель Remnawave запущена"

  if [[ "$proxy_mode" == 'caddy' ]]; then
    local caddy_root="$panel_root/caddy"
    mkdir -p "$caddy_root"
    cat > "$caddy_root/Caddyfile" <<EOF
https://$panel_domain {
    reverse_proxy * http://remnawave:3000
}
:443 {
    tls internal
    respond 204
}
EOF
    cat > "$caddy_root/docker-compose.yml" <<'EOF'
services:
  caddy:
    image: caddy:2.9
    container_name: caddy
    hostname: caddy
    restart: always
    ports:
      - '0.0.0.0:443:443'
      - '0.0.0.0:80:80'
    networks:
      - remnawave-network
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy-ssl-data:/data

networks:
  remnawave-network:
    name: remnawave-network
    driver: bridge
    external: true

volumes:
  caddy-ssl-data:
    driver: local
    external: false
    name: caddy-ssl-data
EOF
    (cd "$caddy_root" && compose_run up -d)
    ok "Caddy для панели поднят"
  else
    warn "Панель установлена локально. Reverse proxy можно добавить позже"
  fi
}

update_bot_now() {
  load_state
  section "Обновить бота"
  local bot_root
  local compose_bin
  bot_root="$(resolve_bot_root)" || { error "Репозиторий бота не найден"; return 1; }
  compose_bin="$(compose_cmd)" || return 1

  printf 'Будет выполнено:\n'
  printf '  cd %s && git pull\n' "$bot_root"
  printf '  cd %s && %s down && %s up -d --build\n' "$bot_root" "$compose_bin" "$compose_bin"

  if confirm "Запустить обновление бота сейчас?"; then
    if (
      cd "$bot_root" &&
      git pull &&
      compose_run down &&
      compose_run up -d --build
    ); then
      ok "Бот обновлён"
    else
      error "Обновление бота завершилось с ошибкой. Текст ошибки показан выше."
      return 1
    fi
  else
    warn "Обновление бота пропущено"
  fi
}

update_cabinet_now() {
  load_state
  section "Обновить кабину"
  local cabinet_root
  local compose_bin
  local compose_file
  cabinet_root="$(resolve_cabinet_root)" || { error "Репозиторий кабины не найден"; return 1; }
  compose_bin="$(compose_cmd)" || return 1
  compose_file="$cabinet_root/bundles/docker-compose.yml"

  printf 'Будет выполнено:\n'
  printf '  cd %s && git pull origin main\n' "$cabinet_root"
  printf '  cd %s && docker builder prune -a -f && %s -f %s down && %s -f %s build --no-cache && %s -f %s up -d\n' \
    "$cabinet_root" "$compose_bin" "$compose_file" "$compose_bin" "$compose_file" "$compose_bin" "$compose_file"

  if confirm "Запустить обновление кабины сейчас?"; then
    if (
      cd "$cabinet_root" &&
      git pull origin main &&
      docker builder prune -a -f &&
      compose_run -f "$compose_file" down &&
      compose_run -f "$compose_file" build --no-cache &&
      compose_run -f "$compose_file" up -d
    ); then
      ok "Кабина обновлена"
    else
      error "Обновление кабины завершилось с ошибкой. Текст ошибки показан выше."
      return 1
    fi
  else
    warn "Обновление кабины пропущено"
  fi
}

integrate_with_existing_remnawave_proxy() {
  load_state

  [[ -n "${EXISTING_REMNAWAVE_DIR:-}" ]] || return 0
  [[ "${INSTALL_MODE:-}" =~ ^(cabinet-only|bot\+cabinet)$ ]] || return 0
  [[ "${PROXY_MODE:-}" == "integrate-remnawave" ]] || return 0

  local proxy_kind="${EXISTING_REMNAWAVE_PROXY_KIND:-unknown}"
  local proxy_config="${EXISTING_REMNAWAVE_PROXY_CONFIG_PATH:-}"
  local integration_conf="$INSTALLER_STATE_DIR/output/${INSTALL_MODE}/proxy.integration.conf"
  local begin_marker="# BEGIN bedolaga-installer"
  local end_marker="# END bedolaga-installer"
  local tmp_file
  local backup_path

  [[ -f "$integration_conf" ]] || { warn "Не найден интеграционный proxy-конфиг: $integration_conf"; return 0; }
  [[ -n "$proxy_config" && -f "$proxy_config" ]] || { warn "Не найден proxy-конфиг Remnawave: ${proxy_config:-unset}"; return 0; }

  section "Интеграция в proxy панели Remnawave"
  tmp_file="$(mktemp)"
  backup_path="${proxy_config}.bedolaga.bak.$(date +%Y%m%d-%H%M%S)"

  cp "$proxy_config" "$backup_path"
  ok "Создал backup proxy-конфига: $backup_path"

  awk -v begin="$begin_marker" -v end="$end_marker" '
    $0 == begin {skip=1; next}
    $0 == end {skip=0; next}
    !skip {print}
  ' "$proxy_config" > "$tmp_file"

  {
    printf '\n%s\n' "$begin_marker"
    cat "$integration_conf"
    printf '\n%s\n' "$end_marker"
  } >> "$tmp_file"

  cp "$tmp_file" "$proxy_config"
  rm -f "$tmp_file"
  ok "Маршруты Bedolaga добавлены в proxy панели"

  case "$proxy_kind" in
    caddy)
      local caddy_root="${EXISTING_REMNAWAVE_DIR}/caddy"
      local compose_file="$caddy_root/docker-compose.yml"
      [[ -f "$compose_file" ]] || { warn "docker-compose панели не найден: $compose_file"; return 0; }
      (
        cd "$caddy_root"
        compose_run up -d
      )
      ok "Caddy панели перезапущен"
      ;;
    nginx)
      if command_exists docker && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'remnawave'; then
        docker exec remnawave nginx -t >/dev/null
        docker restart remnawave >/dev/null
        ok "Nginx панели проверен и перезапущен через контейнер remnawave"
      else
        warn "Nginx-конфиг обновлён, но контейнер remnawave для проверки/рестарта не найден автоматически"
      fi
      ;;
    *)
      warn "Неизвестный тип proxy Remnawave: $proxy_kind"
      ;;
  esac
}
