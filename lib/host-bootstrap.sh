#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BOOTSTRAP_APT_UPDATED=0

os_id() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    printf '%s\n' "${ID:-unknown}"
    return 0
  fi
  printf '%s\n' "unknown"
}

resolve_host_mode() {
  if [[ -n "${HOST_MODE:-}" ]]; then
    printf '%s\n' "$HOST_MODE"
    return 0
  fi
  if detect_existing_remnawave_root >/dev/null 2>&1; then
    printf '%s\n' "coexist"
  else
    printf '%s\n' "clean"
  fi
}

resolve_network_policy() {
  if [[ -n "${NETWORK_POLICY:-}" ]]; then
    printf '%s\n' "$NETWORK_POLICY"
    return 0
  fi
  if [[ "$(resolve_host_mode)" == "coexist" ]]; then
    printf '%s\n' "preserve-existing"
  else
    printf '%s\n' "bootstrap-safe"
  fi
}

resolve_proxy_mode() {
  printf '%s\n' "${PROXY_MODE:-caddy}"
}

apt_update_once() {
  if (( BOOTSTRAP_APT_UPDATED == 0 )); then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    BOOTSTRAP_APT_UPDATED=1
  fi
}

package_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

apt_install_if_missing() {
  local missing=()
  local pkg
  for pkg in "$@"; do
    package_installed "$pkg" || missing+=("$pkg")
  done
  if ((${#missing[@]} == 0)); then
    ok "Packages already present: $*"
    return 0
  fi
  apt_update_once
  log "Installing packages: ${missing[*]}"
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y "${missing[@]}"
}

detect_ssh_ports() {
  local ports=""
  if command_exists sshd; then
    ports="$(sshd -T 2>/dev/null | awk '/^port / {print $2}' | sort -u | xargs echo -n || true)"
  fi
  if [[ -z "$ports" ]]; then
    ports="22"
  fi
  printf '%s\n' "$ports"
}

ufw_is_active() {
  command_exists ufw && ufw status 2>/dev/null | grep -qi '^status: active'
}

allow_ufw_ports() {
  local item
  for item in "$@"; do
    [[ -n "$item" ]] || continue
    ufw allow "$item" >/dev/null
  done
}

configure_firewall_bootstrap_safe() {
  local proxy_mode="$1"
  local ssh_ports
  ssh_ports="$(detect_ssh_ports)"

  apt_install_if_missing ufw

  if ! ufw_is_active; then
    log "Enabling ufw in bootstrap-safe mode"
    ufw default deny incoming >/dev/null
    ufw default allow outgoing >/dev/null
  else
    log "ufw already active; adding required allow rules"
  fi

  local ssh_port
  for ssh_port in $ssh_ports; do
    allow_ufw_ports "$ssh_port/tcp"
  done

  if [[ "$proxy_mode" != "none" ]]; then
    allow_ufw_ports "80/tcp" "443/tcp"
  fi

  if ! ufw_is_active; then
    ufw --force enable >/dev/null
  fi

  ok "Firewall prepared in bootstrap-safe mode"
}

configure_firewall_preserve_existing() {
  local proxy_mode="$1"
  local ssh_ports
  ssh_ports="$(detect_ssh_ports)"

  if ! command_exists ufw; then
    warn "ufw not installed; preserve-existing mode will not enable or reset firewall"
    return 0
  fi

  if ! ufw_is_active; then
    warn "ufw inactive; preserve-existing mode will not enable it automatically"
    return 0
  fi

  local ssh_port
  for ssh_port in $ssh_ports; do
    allow_ufw_ports "$ssh_port/tcp"
  done

  if [[ "$proxy_mode" != "none" ]]; then
    allow_ufw_ports "80/tcp" "443/tcp"
  fi

  ok "Firewall updated additively in preserve-existing mode"
}

ensure_docker_ready() {
  apt_install_if_missing docker.io docker-compose
  systemctl enable --now docker
  docker --version >/dev/null
  compose_cmd >/dev/null
  ok "Docker runtime is ready"
}

ensure_base_tooling() {
  apt_install_if_missing ca-certificates curl git gnupg lsb-release apt-transport-https gettext-base openssl
}

ensure_proxy_package_for_clean_host() {
  local proxy_mode="$1"
  case "$proxy_mode" in
    caddy)
      apt_install_if_missing caddy
      systemctl disable --now caddy >/dev/null 2>&1 || true
      ok "caddy installed for later deploy"
      ;;
    nginx)
      apt_install_if_missing nginx
      systemctl disable --now nginx >/dev/null 2>&1 || true
      ok "nginx installed for later deploy"
      ;;
    integrate-remnawave)
      ok "Local Remnawave proxy integration selected, separate proxy package not needed"
      ;;
    none)
      ok "No reverse proxy package requested"
      ;;
    *)
      warn "Unknown PROXY_MODE=$proxy_mode, skipping reverse proxy package"
      ;;
  esac
}

show_host_bootstrap_plan() {
  load_state
  section "Host bootstrap plan"
  local mode network proxy detected
  mode="$(resolve_host_mode)"
  network="$(resolve_network_policy)"
  proxy="$(resolve_proxy_mode)"
  detected="${EXISTING_REMNAWAVE_DIR:-$(detect_existing_remnawave_root 2>/dev/null || true)}"

  printf '  os: %s\n' "$(os_id)"
  printf '  host mode: %s\n' "$mode"
  printf '  network policy: %s\n' "$network"
  printf '  proxy mode: %s\n' "$proxy"
  printf '  existing remnawave: %s\n' "${detected:-not-detected}"
}

run_host_bootstrap() {
  load_state
  section "Host bootstrap"

  [[ "$(os_id)" =~ ^(debian|ubuntu)$ ]] || {
    error "Host bootstrap currently supports Debian/Ubuntu only"
    return 1
  }

  if ! is_root; then
    error "Host bootstrap requires root"
    return 1
  fi

  local mode network proxy
  mode="$(resolve_host_mode)"
  network="$(resolve_network_policy)"
  proxy="$(resolve_proxy_mode)"

  show_host_bootstrap_plan
  ensure_base_tooling
  ensure_docker_ready

  if [[ "$mode" == "clean" ]]; then
    ensure_proxy_package_for_clean_host "$proxy"
  else
    warn "Coexist mode: reverse proxy package install is skipped by default to avoid touching existing host services"
  fi

  case "$network" in
    bootstrap-safe)
      configure_firewall_bootstrap_safe "$proxy"
      ;;
    preserve-existing)
      configure_firewall_preserve_existing "$proxy"
      ;;
    *)
      error "Unknown network policy: $network"
      return 1
      ;;
  esac

  ok "Host bootstrap completed"
}
