#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

render_scaffold() {
  load_state
  section "Rendering scaffold"

  local target_root="$INSTALLER_STATE_DIR/output/${INSTALL_MODE:-unknown}"
  mkdir -p "$target_root"

  export BOT_TOKEN="${BOT_TOKEN_VALUE:-}"
  export ADMIN_IDS="${ADMIN_IDS_VALUE:-}"
  export TZ="${TZ_VALUE:-Europe/Moscow}"
  export REMNAWAVE_API_URL="${REMNAWAVE_API_URL_VALUE:-}"
  export REMNAWAVE_AUTH_TYPE="${REMNAWAVE_AUTH_TYPE_VALUE:-api_key}"
  export REMNAWAVE_API_KEY="${REMNAWAVE_API_KEY_VALUE:-}"
  export REMNAWAVE_USERNAME="${REMNAWAVE_USERNAME_VALUE:-}"
  export REMNAWAVE_PASSWORD="${REMNAWAVE_PASSWORD_VALUE:-}"
  export REMNAWAVE_CADDY_TOKEN="${REMNAWAVE_CADDY_TOKEN_VALUE:-}"
  export POSTGRES_PASSWORD="${BOT_POSTGRES_PASSWORD:-}"
  export BOT_LOCAL_PORT="${BOT_LOCAL_PORT:-8080}"
  export CABINET_LOCAL_PORT="${CABINET_LOCAL_PORT:-3020}"
  export WEB_API_DEFAULT_TOKEN="${BOT_WEB_API_TOKEN:-}"
  export CABINET_JWT_SECRET="${CABINET_JWT_SECRET_VALUE:-}"
  export CABINET_DOMAIN="${CABINET_DOMAIN_VALUE:-}"
  export VITE_TELEGRAM_BOT_USERNAME="${VITE_TELEGRAM_BOT_USERNAME_VALUE:-}"
  export VITE_APP_NAME="${VITE_APP_NAME_VALUE:-VPN Cabinet}"
  export VITE_APP_LOGO="${VITE_APP_LOGO_VALUE:-V}"

  case "${INSTALL_MODE:-}" in
    bot-only)
      render_template "$INSTALLER_TEMPLATES_DIR/env.bot.tmpl" "$target_root/.env"
      ;;
    cabinet-only)
      render_template "$INSTALLER_TEMPLATES_DIR/env.cabinet.tmpl" "$target_root/.env"
      if [[ "${PROXY_MODE:-}" == "integrate-remnawave" ]]; then
        case "${EXISTING_REMNAWAVE_PROXY_KIND:-unknown}" in
          nginx)
            render_template "$INSTALLER_TEMPLATES_DIR/nginx.integrate-remnawave.conf.tmpl" "$target_root/proxy.integration.conf"
            ;;
          *)
            render_template "$INSTALLER_TEMPLATES_DIR/Caddyfile.integrate-remnawave.tmpl" "$target_root/proxy.integration.conf"
            ;;
        esac
      else
        render_template "$INSTALLER_TEMPLATES_DIR/Caddyfile.cabinet.tmpl" "$target_root/Caddyfile"
      fi
      ;;
    bot+cabinet)
      render_template "$INSTALLER_TEMPLATES_DIR/env.bot.tmpl" "$target_root/.env.bot"
      render_template "$INSTALLER_TEMPLATES_DIR/env.cabinet.tmpl" "$target_root/.env.cabinet"
      if [[ "${PROXY_MODE:-}" == "integrate-remnawave" ]]; then
        case "${EXISTING_REMNAWAVE_PROXY_KIND:-unknown}" in
          nginx)
            render_template "$INSTALLER_TEMPLATES_DIR/nginx.integrate-remnawave.conf.tmpl" "$target_root/proxy.integration.conf"
            ;;
          *)
            render_template "$INSTALLER_TEMPLATES_DIR/Caddyfile.integrate-remnawave.tmpl" "$target_root/proxy.integration.conf"
            ;;
        esac
      else
        render_template "$INSTALLER_TEMPLATES_DIR/Caddyfile.combined.tmpl" "$target_root/Caddyfile"
      fi
      ;;
    *)
      error "Unknown INSTALL_MODE: ${INSTALL_MODE:-unset}"
      return 1
      ;;
  esac

  ok "Scaffold rendered to $target_root"
}
