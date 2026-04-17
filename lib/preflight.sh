#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

run_preflight() {
  load_state
  section "Preflight"

  local failures=0
  local detected_remnawave=""

  if is_root; then ok "Running as root"; else warn "Not running as root (sudo/root will be needed for real deploy)"; fi

  detected_remnawave="${EXISTING_REMNAWAVE_DIR:-}"
  if [[ -z "$detected_remnawave" ]]; then
    detected_remnawave="$(detect_existing_remnawave_root 2>/dev/null || true)"
  fi
  if [[ -n "$detected_remnawave" ]]; then
    warn "Existing Remnawave detected at $detected_remnawave"
    warn "Treat this host as coexist/preserve-existing by default"
  else
    ok "No existing /opt/remnawave* installation detected"
  fi

  if [[ -n "${HOST_MODE:-}" ]]; then
    ok "host mode: ${HOST_MODE}"
  fi
  if [[ -n "${NETWORK_POLICY:-}" ]]; then
    ok "network policy: ${NETWORK_POLICY}"
  fi
  if [[ -n "${BOT_LOCAL_PORT:-}" ]]; then
    ok "bot local port: ${BOT_LOCAL_PORT}"
  fi
  if [[ -n "${CABINET_LOCAL_PORT:-}" ]]; then
    ok "cabinet local port: ${CABINET_LOCAL_PORT}"
  fi

  if command_exists docker; then ok "docker present"; else error "docker not found"; ((failures++)); fi
  if has_docker_compose_plugin; then
    ok "docker compose plugin present"
  elif has_docker_compose_legacy; then
    ok "docker-compose present"
  else
    error "docker compose command not found (need plugin or legacy docker-compose)"
    ((failures++))
  fi
  if command_exists git; then ok "git present"; else error "git not found"; ((failures++)); fi
  if command_exists curl; then ok "curl present"; else error "curl not found"; ((failures++)); fi
  if command_exists openssl; then ok "openssl present"; else warn "openssl not found (secret generation fallback will be weaker)"; fi

  if [[ -r /etc/os-release ]]; then
    local os_info
    os_info=$(tr '\n' ' ' </etc/os-release)
    ok "os-release detected"
    printf "%s\n" "$os_info" | sed 's/^/    /'
  fi

  if command_exists ss; then
    local used_ports
    used_ports=$(ss -ltn '( sport = :80 or sport = :443 )' 2>/dev/null | tail -n +2 || true)
    if [[ -n "$used_ports" ]]; then
      warn "Ports 80/443 already in use"
      printf "%s\n" "$used_ports" | sed 's/^/    /'
    else
      ok "Ports 80/443 look free"
    fi

    local opt_ports
    opt_ports=$(ss -ltnp 2>/dev/null | grep -F '/opt/' || true)
    if [[ -n "$opt_ports" ]]; then
      warn "Detected listening processes with /opt-based executables"
      printf "%s\n" "$opt_ports" | sed 's/^/    /'
    fi

    if [[ -n "${BOT_LOCAL_PORT:-}" ]] && validate_tcp_port "${BOT_LOCAL_PORT}"; then
      local bot_port_use
      bot_port_use=$(port_listener_summary "${BOT_LOCAL_PORT}")
      if [[ -n "$bot_port_use" ]]; then
        warn "Configured bot local port ${BOT_LOCAL_PORT} is already in use"
        printf "%s\n" "$bot_port_use" | sed 's/^/    /'
        local bot_suggest
        bot_suggest=$(next_free_tcp_port 18080 18120 || true)
        [[ -n "$bot_suggest" ]] && warn "Suggested free bot port: $bot_suggest"
      else
        ok "Configured bot local port ${BOT_LOCAL_PORT} looks free"
      fi
    fi

    if [[ -n "${CABINET_LOCAL_PORT:-}" ]] && validate_tcp_port "${CABINET_LOCAL_PORT}"; then
      local cabinet_port_use
      cabinet_port_use=$(port_listener_summary "${CABINET_LOCAL_PORT}")
      if [[ -n "$cabinet_port_use" ]]; then
        warn "Configured cabinet local port ${CABINET_LOCAL_PORT} is already in use"
        printf "%s\n" "$cabinet_port_use" | sed 's/^/    /'
        local cabinet_suggest
        cabinet_suggest=$(next_free_tcp_port 13020 13080 || true)
        [[ -n "$cabinet_suggest" ]] && warn "Suggested free cabinet port: $cabinet_suggest"
      else
        ok "Configured cabinet local port ${CABINET_LOCAL_PORT} looks free"
      fi
    fi
  fi

  df -h / | sed 's/^/    /'
  free -m 2>/dev/null | sed 's/^/    /' || true

  if ((failures > 0)); then
    warn "Preflight finished with $failures blocking issue(s)"
    return 1
  fi

  ok "Preflight passed"
}
