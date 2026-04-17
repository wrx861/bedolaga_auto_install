#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

materialize_bot_bundle() {
  load_state
  local src_root="${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}"
  local bundle_root="${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}/bundles"
  local render_root="$INSTALLER_STATE_DIR/output/${INSTALL_MODE}"
  mkdir -p "$bundle_root"

  export BOT_LOCAL_PORT="${BOT_LOCAL_PORT:-8080}"
  export BOT_HOST_PORT="${BOT_LOCAL_PORT:-8080}"

  if [[ -f "$render_root/.env.bot" ]]; then
    cp "$render_root/.env.bot" "$bundle_root/.env"
  elif [[ -f "$render_root/.env" ]]; then
    cp "$render_root/.env" "$bundle_root/.env"
  else
    error "Bot env scaffold not found in $render_root"
    return 1
  fi

  if [[ -f "$INSTALLER_TEMPLATES_DIR/docker-compose.bot.override.tmpl" ]]; then
    render_template "$INSTALLER_TEMPLATES_DIR/docker-compose.bot.override.tmpl" "$bundle_root/docker-compose.override.yml"
  fi

  cat > "$bundle_root/DEPLOY_BOT.txt" <<EOF
Bot bundle prepared
===================
Source repo: $src_root
Bundle dir:  $bundle_root

Planned command sequence:
cd "$src_root"
cp "$bundle_root/.env" .env
$(compose_cmd) -f docker-compose.yml -f "$bundle_root/docker-compose.override.yml" up -d
EOF
}

materialize_cabinet_bundle() {
  load_state
  local src_root="${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}"
  local bundle_root="${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}/bundles"
  local render_root="$INSTALLER_STATE_DIR/output/${INSTALL_MODE}"
  mkdir -p "$bundle_root"

  export CABINET_LOCAL_PORT="${CABINET_LOCAL_PORT:-3020}"

  if [[ -f "$render_root/.env.cabinet" ]]; then
    cp "$render_root/.env.cabinet" "$bundle_root/.env"
  elif [[ -f "$render_root/.env" ]]; then
    cp "$render_root/.env" "$bundle_root/.env"
  else
    warn "Cabinet env scaffold not found in $render_root"
  fi

  render_template "$INSTALLER_TEMPLATES_DIR/docker-compose.cabinet.yml.tmpl" "$bundle_root/docker-compose.yml"

  cat > "$bundle_root/DEPLOY_CABINET.txt" <<EOF
Cabinet bundle prepared
=======================
Source repo: $src_root
Bundle dir:  $bundle_root

Planned command sequence:
cd "$src_root"
cp "$bundle_root/.env" .env
$(compose_cmd) -f "$bundle_root/docker-compose.yml" up -d
EOF
}

materialize_proxy_bundle() {
  load_state

  if [[ "${PROXY_MODE:-}" == "integrate-remnawave" || "${PROXY_MODE:-}" == "none" ]]; then
    return 0
  fi

  local proxy_root="${PROXY_INSTALL_DIR:-/opt/bedolaga-proxy}"
  mkdir -p "$proxy_root"

  if [[ -f "$INSTALLER_STATE_DIR/output/${INSTALL_MODE}/Caddyfile" ]]; then
    cp "$INSTALLER_STATE_DIR/output/${INSTALL_MODE}/Caddyfile" "$proxy_root/Caddyfile"
  fi
}

materialize_install_bundles() {
  load_state
  section "Materializing install bundles"

  case "${INSTALL_MODE:-}" in
    bot-only)
      materialize_bot_bundle
      ;;
    cabinet-only)
      materialize_cabinet_bundle
      materialize_proxy_bundle
      ;;
    bot+cabinet)
      materialize_bot_bundle
      materialize_cabinet_bundle
      materialize_proxy_bundle
      ;;
    *)
      error "INSTALL_MODE not set"
      return 1
      ;;
  esac

  ok "Install bundles written"
}
