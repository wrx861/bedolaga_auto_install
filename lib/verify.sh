#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

run_verify_skeleton() {
  load_state
  section "Verify skeleton"

  [[ -d "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}" ]] && ok "bot dir exists" || warn "bot dir missing"
  [[ -d "${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}" ]] && ok "cabinet dir exists" || warn "cabinet dir missing"
  [[ -d "${PROXY_INSTALL_DIR:-/opt/bedolaga-proxy}" ]] && ok "proxy dir exists" || warn "proxy dir missing"

  [[ -d "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}/generated" ]] && ok "bot generated dir exists" || warn "bot generated dir missing"
  [[ -d "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}/bundles" ]] && ok "bot bundles dir exists" || warn "bot bundles dir missing"
  [[ -f "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}/INSTALLER_NEXT_STEPS.txt" ]] && ok "bot next steps exists" || warn "bot next steps missing"
}
