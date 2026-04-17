#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

write_install_metadata() {
  load_state
  section "Writing install metadata"

  local timestamp
  timestamp="$(date -Is)"

  if [[ -n "${BOT_INSTALL_DIR:-}" ]]; then
    mkdir -p "$BOT_INSTALL_DIR"
    cat > "$BOT_INSTALL_DIR/.bedolaga-installer-meta" <<EOF
installedAt=$timestamp
installMode=${INSTALL_MODE:-}
proxyMode=${PROXY_MODE:-}
hostMode=${HOST_MODE:-}
networkPolicy=${NETWORK_POLICY:-}
existingRemnawaveDir=${EXISTING_REMNAWAVE_DIR:-}
timezone=${TZ_VALUE:-}
botLocalPort=${BOT_LOCAL_PORT:-}
cabinetLocalPort=${CABINET_LOCAL_PORT:-}
role=bot
remnawaveSetupMode=${REMNAWAVE_SETUP_MODE:-now}
cabinetDir=${CABINET_INSTALL_DIR:-}
proxyDir=${PROXY_INSTALL_DIR:-}
proxyIntegrationTarget=${EXISTING_REMNAWAVE_DIR:-}
EOF
  fi

  if [[ -n "${CABINET_INSTALL_DIR:-}" ]]; then
    mkdir -p "$CABINET_INSTALL_DIR"
    cat > "$CABINET_INSTALL_DIR/.bedolaga-installer-meta" <<EOF
installedAt=$timestamp
installMode=${INSTALL_MODE:-}
proxyMode=${PROXY_MODE:-}
hostMode=${HOST_MODE:-}
networkPolicy=${NETWORK_POLICY:-}
existingRemnawaveDir=${EXISTING_REMNAWAVE_DIR:-}
timezone=${TZ_VALUE:-}
botLocalPort=${BOT_LOCAL_PORT:-}
cabinetLocalPort=${CABINET_LOCAL_PORT:-}
role=cabinet
remnawaveSetupMode=${REMNAWAVE_SETUP_MODE:-now}
botDir=${BOT_INSTALL_DIR:-}
proxyDir=${PROXY_INSTALL_DIR:-}
proxyIntegrationTarget=${EXISTING_REMNAWAVE_DIR:-}
EOF
  fi

  if [[ -n "${PROXY_INSTALL_DIR:-}" && "${PROXY_MODE:-}" != "integrate-remnawave" && "${PROXY_MODE:-}" != "none" ]]; then
    mkdir -p "$PROXY_INSTALL_DIR"
    cat > "$PROXY_INSTALL_DIR/.bedolaga-installer-meta" <<EOF
installedAt=$timestamp
installMode=${INSTALL_MODE:-}
proxyMode=${PROXY_MODE:-}
hostMode=${HOST_MODE:-}
networkPolicy=${NETWORK_POLICY:-}
existingRemnawaveDir=${EXISTING_REMNAWAVE_DIR:-}
timezone=${TZ_VALUE:-}
botLocalPort=${BOT_LOCAL_PORT:-}
cabinetLocalPort=${CABINET_LOCAL_PORT:-}
role=proxy
remnawaveSetupMode=${REMNAWAVE_SETUP_MODE:-now}
botDir=${BOT_INSTALL_DIR:-}
cabinetDir=${CABINET_INSTALL_DIR:-}
proxyIntegrationTarget=${EXISTING_REMNAWAVE_DIR:-}
EOF
  fi

  ok "Install metadata written"
}
