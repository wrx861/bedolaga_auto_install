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
