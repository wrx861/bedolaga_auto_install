#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

verify_bot_live() {
  load_state
  section "Live verify: bot"
  local bot_root="${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}"
  local port="${BOT_LOCAL_PORT:-8080}"
  local host_port="${BOT_LOCAL_PORT:-8080}"
  local api_token="${BOT_WEB_API_TOKEN:-}"
  local setup_mode="${REMNAWAVE_SETUP_MODE:-now}"
  local ok_count=0
  local attempt
  local max_attempts="${LIVE_VERIFY_ATTEMPTS:-12}"
  local sleep_seconds="${LIVE_VERIFY_SLEEP_SECONDS:-5}"

  if [[ -z "$api_token" && -f "$bot_root/.env" ]]; then
    api_token=$(grep -E '^WEB_API_DEFAULT_TOKEN=' "$bot_root/.env" 2>/dev/null | cut -d= -f2- || true)
  fi

  if [[ -f "$bot_root/.env" ]]; then
    host_port=$(grep -E '^BOT_HOST_PORT=' "$bot_root/.env" 2>/dev/null | cut -d= -f2- || true)
    host_port="${host_port:-$port}"
  else
    host_port="$port"
  fi

  if (cd "$bot_root" && compose_run ps >/dev/null 2>&1); then
    ok "compose ps reachable for bot"
    ((ok_count+=1))
  else
    warn "compose ps failed for bot"
  fi

  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    if [[ -n "$api_token" ]] && curl -fsS -H "X-API-Key: ${api_token}" "http://127.0.0.1:${host_port}/health" >/dev/null 2>&1; then
      ok "bot /health responded on 127.0.0.1:${host_port}"
      ((ok_count+=1))
      break
    fi
    if (( attempt < max_attempts )); then
      warn "bot /health not responding yet on 127.0.0.1:${host_port}, retry ${attempt}/${max_attempts}"
      sleep "$sleep_seconds"
    else
      warn "bot /health not responding yet on 127.0.0.1:${host_port}"
    fi
  done

  if [[ "$setup_mode" == "later" ]]; then
    warn "Remnawave API пока не подключён — это нормально"
    ok "Бот установлен. API можно подключить позже"
    return 0
  fi

  [[ $ok_count -gt 0 ]]
}

verify_cabinet_live() {
  load_state
  section "Live verify: cabinet"
  local cabinet_root="${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}"
  local port="${CABINET_LOCAL_PORT:-3020}"
  local ok_count=0
  local attempt
  local max_attempts="${LIVE_VERIFY_ATTEMPTS:-12}"
  local sleep_seconds="${LIVE_VERIFY_SLEEP_SECONDS:-5}"

  if [[ -f "$cabinet_root/bundles/.env" ]]; then
    port=$(grep -E '^CABINET_LOCAL_PORT=' "$cabinet_root/bundles/.env" 2>/dev/null | cut -d= -f2- || true)
    port="${port:-${CABINET_LOCAL_PORT:-3020}}"
  elif [[ -f "$cabinet_root/.env" ]]; then
    port=$(grep -E '^CABINET_LOCAL_PORT=' "$cabinet_root/.env" 2>/dev/null | cut -d= -f2- || true)
    port="${port:-${CABINET_LOCAL_PORT:-3020}}"
  fi

  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    if curl -fsS "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
      ok "cabinet responded on 127.0.0.1:${port}"
      ((ok_count+=1))
      break
    fi
    if (( attempt < max_attempts )); then
      warn "cabinet not responding yet on 127.0.0.1:${port}, retry ${attempt}/${max_attempts}"
      sleep "$sleep_seconds"
    else
      warn "cabinet not responding yet on 127.0.0.1:${port}"
    fi
  done

  [[ $ok_count -gt 0 ]]
}
