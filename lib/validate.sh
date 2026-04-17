#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=host-bootstrap.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/host-bootstrap.sh"

require_nonempty() {
  local name="$1"
  local value="${2:-}"
  if [[ -z "$value" ]]; then
    error "Required value missing: $name"
    return 1
  fi
}

validate_session_inputs() {
  load_state
  section "Validate session inputs"

  local failures=0

  if [[ -z "${HOST_MODE:-}" ]]; then
    HOST_MODE="$(resolve_host_mode 2>/dev/null || true)"
    [[ -n "${HOST_MODE:-}" ]] && ok "Resolved HOST_MODE=${HOST_MODE}"
  fi
  if [[ -z "${NETWORK_POLICY:-}" ]]; then
    NETWORK_POLICY="$(resolve_network_policy 2>/dev/null || true)"
    [[ -n "${NETWORK_POLICY:-}" ]] && ok "Resolved NETWORK_POLICY=${NETWORK_POLICY}"
  fi
  if [[ -z "${BOT_LOCAL_PORT:-}" ]]; then
    BOT_LOCAL_PORT=8080
    ok "Defaulted BOT_LOCAL_PORT=${BOT_LOCAL_PORT}"
  fi
  if [[ -z "${CABINET_LOCAL_PORT:-}" ]]; then
    CABINET_LOCAL_PORT=3020
    ok "Defaulted CABINET_LOCAL_PORT=${CABINET_LOCAL_PORT}"
  fi

  require_nonempty INSTALL_MODE "${INSTALL_MODE:-}" || ((failures++))
  require_nonempty PROXY_MODE "${PROXY_MODE:-}" || ((failures++))
  require_nonempty TZ_VALUE "${TZ_VALUE:-}" || ((failures++))
  require_nonempty HOST_MODE "${HOST_MODE:-}" || ((failures++))
  require_nonempty NETWORK_POLICY "${NETWORK_POLICY:-}" || ((failures++))
  require_nonempty BOT_LOCAL_PORT "${BOT_LOCAL_PORT:-}" || ((failures++))
  require_nonempty CABINET_LOCAL_PORT "${CABINET_LOCAL_PORT:-}" || ((failures++))

  case "${HOST_MODE:-}" in
    clean|coexist) ;;
    *) error "Unknown HOST_MODE: ${HOST_MODE:-unset}"; ((failures++)) ;;
  esac

  case "${NETWORK_POLICY:-}" in
    preserve-existing|bootstrap-safe) ;;
    *) error "Unknown NETWORK_POLICY: ${NETWORK_POLICY:-unset}"; ((failures++)) ;;
  esac

  case "${PROXY_MODE:-}" in
    caddy|nginx|integrate-remnawave|none) ;;
    *) error "Unknown PROXY_MODE: ${PROXY_MODE:-unset}"; ((failures++)) ;;
  esac

  validate_tcp_port "${BOT_LOCAL_PORT:-}" || { error "Invalid BOT_LOCAL_PORT=${BOT_LOCAL_PORT:-unset}"; ((failures++)); }
  validate_tcp_port "${CABINET_LOCAL_PORT:-}" || { error "Invalid CABINET_LOCAL_PORT=${CABINET_LOCAL_PORT:-unset}"; ((failures++)); }

  if [[ "${BOT_LOCAL_PORT:-}" == "${CABINET_LOCAL_PORT:-}" ]]; then
    error "BOT_LOCAL_PORT and CABINET_LOCAL_PORT must be different"
    ((failures++))
  fi

  if [[ "${HOST_MODE:-}" == "coexist" && "${NETWORK_POLICY:-}" != "preserve-existing" ]]; then
    error "HOST_MODE=coexist requires NETWORK_POLICY=preserve-existing"
    ((failures++))
  fi

  if [[ -z "${REMNAWAVE_SETUP_MODE:-}" ]]; then
    REMNAWAVE_SETUP_MODE="now"
  fi

  case "${INSTALL_MODE:-}" in
    bot-only)
      require_nonempty BOT_INSTALL_DIR "${BOT_INSTALL_DIR:-}" || ((failures++))
      require_nonempty BOT_TOKEN_VALUE "${BOT_TOKEN_VALUE:-}" || ((failures++))
      require_nonempty ADMIN_IDS_VALUE "${ADMIN_IDS_VALUE:-}" || ((failures++))
      require_nonempty REMNAWAVE_AUTH_TYPE_VALUE "${REMNAWAVE_AUTH_TYPE_VALUE:-}" || ((failures++))
      if [[ "${REMNAWAVE_SETUP_MODE:-now}" != "later" ]]; then
        require_nonempty REMNAWAVE_API_URL_VALUE "${REMNAWAVE_API_URL_VALUE:-}" || ((failures++))
      fi
      ;;
    cabinet-only)
      require_nonempty CABINET_INSTALL_DIR "${CABINET_INSTALL_DIR:-}" || ((failures++))
      require_nonempty CABINET_DOMAIN_VALUE "${CABINET_DOMAIN_VALUE:-}" || ((failures++))
      require_nonempty VITE_TELEGRAM_BOT_USERNAME_VALUE "${VITE_TELEGRAM_BOT_USERNAME_VALUE:-}" || ((failures++))
      ;;
    bot+cabinet)
      require_nonempty BOT_INSTALL_DIR "${BOT_INSTALL_DIR:-}" || ((failures++))
      require_nonempty CABINET_INSTALL_DIR "${CABINET_INSTALL_DIR:-}" || ((failures++))
      require_nonempty BOT_TOKEN_VALUE "${BOT_TOKEN_VALUE:-}" || ((failures++))
      require_nonempty ADMIN_IDS_VALUE "${ADMIN_IDS_VALUE:-}" || ((failures++))
      require_nonempty REMNAWAVE_AUTH_TYPE_VALUE "${REMNAWAVE_AUTH_TYPE_VALUE:-}" || ((failures++))
      if [[ "${REMNAWAVE_SETUP_MODE:-now}" != "later" ]]; then
        require_nonempty REMNAWAVE_API_URL_VALUE "${REMNAWAVE_API_URL_VALUE:-}" || ((failures++))
      fi
      require_nonempty CABINET_DOMAIN_VALUE "${CABINET_DOMAIN_VALUE:-}" || ((failures++))
      require_nonempty VITE_TELEGRAM_BOT_USERNAME_VALUE "${VITE_TELEGRAM_BOT_USERNAME_VALUE:-}" || ((failures++))
      ;;
    *)
      error "Unknown INSTALL_MODE: ${INSTALL_MODE:-unset}"
      ((failures++))
      ;;
  esac

  case "${REMNAWAVE_AUTH_TYPE_VALUE:-}" in
    api_key)
      if [[ "${INSTALL_MODE:-}" != cabinet-only && "${REMNAWAVE_SETUP_MODE:-now}" != "later" ]]; then
        require_nonempty REMNAWAVE_API_KEY_VALUE "${REMNAWAVE_API_KEY_VALUE:-}" || ((failures++))
      fi
      ;;
    basic_auth)
      if [[ "${INSTALL_MODE:-}" != cabinet-only && "${REMNAWAVE_SETUP_MODE:-now}" != "later" ]]; then
        require_nonempty REMNAWAVE_USERNAME_VALUE "${REMNAWAVE_USERNAME_VALUE:-}" || ((failures++))
        require_nonempty REMNAWAVE_PASSWORD_VALUE "${REMNAWAVE_PASSWORD_VALUE:-}" || ((failures++))
      fi
      ;;
    caddy)
      if [[ "${INSTALL_MODE:-}" != cabinet-only && "${REMNAWAVE_SETUP_MODE:-now}" != "later" ]]; then
        require_nonempty REMNAWAVE_CADDY_TOKEN_VALUE "${REMNAWAVE_CADDY_TOKEN_VALUE:-}" || ((failures++))
      fi
      ;;
    '' ) ;;
    * ) warn "Unknown REMNAWAVE_AUTH_TYPE_VALUE=${REMNAWAVE_AUTH_TYPE_VALUE:-}" ;;
  esac

  if command_exists ss; then
    if [[ "${INSTALLER_ALLOW_IN_USE_PORTS:-}" =~ ^(1|true|yes|on)$ ]]; then
      warn "Skipping port-in-use hard failure checks (INSTALLER_ALLOW_IN_USE_PORTS)"
    else
      if [[ "${INSTALL_MODE:-}" =~ ^(bot-only|bot\+cabinet)$ ]] && is_port_in_use "${BOT_LOCAL_PORT:-}"; then
        error "BOT_LOCAL_PORT ${BOT_LOCAL_PORT} is already in use"
        port_listener_summary "${BOT_LOCAL_PORT}" | sed 's/^/    /'
        local bot_suggest
        bot_suggest=$(next_free_tcp_port 18080 18120 || true)
        [[ -n "$bot_suggest" ]] && warn "Suggested BOT_LOCAL_PORT=$bot_suggest"
        ((failures++))
      fi
      if [[ "${INSTALL_MODE:-}" =~ ^(cabinet-only|bot\+cabinet)$ ]] && is_port_in_use "${CABINET_LOCAL_PORT:-}"; then
        error "CABINET_LOCAL_PORT ${CABINET_LOCAL_PORT} is already in use"
        port_listener_summary "${CABINET_LOCAL_PORT}" | sed 's/^/    /'
        local cabinet_suggest
        cabinet_suggest=$(next_free_tcp_port 13020 13080 || true)
        [[ -n "$cabinet_suggest" ]] && warn "Suggested CABINET_LOCAL_PORT=$cabinet_suggest"
        ((failures++))
      fi
    fi
  fi

  if ((failures > 0)); then
    error "Validation failed with $failures issue(s)"
    return 1
  fi

  ok "Session inputs look complete"
}
