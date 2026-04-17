#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=host-bootstrap.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/host-bootstrap.sh"
# shellcheck source=runtime-actions.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/runtime-actions.sh"
# shellcheck source=live-verify.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/live-verify.sh"

run_full_deploy_pipeline() {
  load_state
  section "Full deploy pipeline"

  export INSTALLER_ASSUME_YES=1

  run_host_bootstrap

  case "${INSTALL_MODE:-}" in
    bot-only)
      install_bot_now
      verify_bot_live || true
      ;;
    cabinet-only)
      install_cabinet_now
      verify_cabinet_live || true
      ;;
    bot+cabinet)
      install_bot_now
      verify_bot_live || true
      install_cabinet_now
      verify_cabinet_live || true
      ;;
    *)
      error "INSTALL_MODE not set"
      return 1
      ;;
  esac

  ok "Full deploy pipeline finished"
}
