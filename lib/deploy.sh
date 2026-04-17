#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=render.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/render.sh"

prepare_layout() {
  load_state
  section "Preparing layout"

  mkdir -p "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}"
  mkdir -p "${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}"
  mkdir -p "${PROXY_INSTALL_DIR:-/opt/bedolaga-proxy}"
  mkdir -p "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}/generated"
  mkdir -p "${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}/generated"
  mkdir -p "${PROXY_INSTALL_DIR:-/opt/bedolaga-proxy}/generated"

  ok "Created separate layout for bot/cabinet/proxy"
}

copy_rendered_artifacts() {
  load_state
  section "Copying rendered artifacts"

  local render_root="$INSTALLER_STATE_DIR/output/${INSTALL_MODE:-unknown}"

  if [[ ! -d "$render_root" ]]; then
    error "Nothing rendered yet at $render_root"
    return 1
  fi

  if [[ -f "$render_root/.env" || -f "$render_root/.env.bot" ]]; then
    mkdir -p "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}/generated"
    cp -R "$render_root"/. "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}/generated/"
  fi

  if [[ -f "$render_root/.env.cabinet" ]]; then
    mkdir -p "${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}/generated"
    cp -R "$render_root"/. "${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}/generated/"
  fi

  if [[ -f "$render_root/Caddyfile" ]]; then
    mkdir -p "${PROXY_INSTALL_DIR:-/opt/bedolaga-proxy}/generated"
    cp -R "$render_root"/. "${PROXY_INSTALL_DIR:-/opt/bedolaga-proxy}/generated/"
  fi

  ok "Artifacts copied into separate generated dirs"
}

write_next_steps() {
  load_state
  local bot_root="${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}"
  local cabinet_root="${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}"
  local proxy_root="${PROXY_INSTALL_DIR:-/opt/bedolaga-proxy}"

  cat > "$bot_root/INSTALLER_NEXT_STEPS.txt" <<EOF
Bedolaga installer next steps
============================

Mode: ${INSTALL_MODE:-unknown}
Host mode: ${HOST_MODE:-unset}
Network policy: ${NETWORK_POLICY:-unset}
Existing Remnawave dir: ${EXISTING_REMNAWAVE_DIR:-not-detected}
Bot local port: ${BOT_LOCAL_PORT:-8080}
Cabinet local port: ${CABINET_LOCAL_PORT:-3020}
Bot dir: ${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}
Cabinet dir: ${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}
Proxy dir: ${PROXY_INSTALL_DIR:-/opt/bedolaga-proxy}
Proxy mode: ${PROXY_MODE:-unset}

Update model (target):
- bot update: cd ${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot} && git pull
- cabinet update: cd ${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet} && git pull
- future: expose these through installer menu as update actions

Planned next implementation steps:
1. Clone/pull upstream bot repo into: $bot_root
2. Clone/pull upstream cabinet repo into: $cabinet_root
3. Materialize docker compose files/overrides
4. Materialize Caddy/Nginx config under $proxy_root
5. Run compose up -d
6. Run health verification

Firewall/network safety policy:
- preserve-existing means do not close unrelated open ports on an existing host
- if existing Remnawave or other services are detected, only additive firewall changes are allowed by default
EOF

  cp "$bot_root/INSTALLER_NEXT_STEPS.txt" "$cabinet_root/INSTALLER_NEXT_STEPS.txt" 2>/dev/null || true
  cp "$bot_root/INSTALLER_NEXT_STEPS.txt" "$proxy_root/INSTALLER_NEXT_STEPS.txt" 2>/dev/null || true
  ok "Wrote NEXT_STEPS file"
}

run_deploy_skeleton() {
  prepare_layout
  copy_rendered_artifacts
  write_next_steps
}
