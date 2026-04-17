#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

run_verify_skeleton() {
  load_state
  section "Verify skeleton"

  [[ -d "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}" ]] && ok "bot dir exists" || warn "bot dir missing"
  [[ -d "${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}" ]] && ok "cabinet dir exists" || warn "cabinet dir missing"

  if [[ "${PROXY_MODE:-}" == "integrate-remnawave" ]]; then
    ok "proxy integration mode selected"
    [[ -n "${EXISTING_REMNAWAVE_PROXY_CONFIG_PATH:-}" ]] && ok "panel proxy config detected: ${EXISTING_REMNAWAVE_PROXY_CONFIG_PATH}" || warn "panel proxy config not detected"
  elif [[ "${PROXY_MODE:-}" == "none" ]]; then
    ok "proxy not required"
  else
    [[ -d "${PROXY_INSTALL_DIR:-/opt/bedolaga-proxy}" ]] && ok "proxy dir exists" || warn "proxy dir missing"
  fi

  [[ -d "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}/generated" ]] && ok "bot generated dir exists" || warn "bot generated dir missing"
  [[ -d "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}/bundles" ]] && ok "bot bundles dir exists" || warn "bot bundles dir missing"
  [[ -f "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}/INSTALLER_NEXT_STEPS.txt" ]] && ok "bot next steps exists" || warn "bot next steps missing"
}
