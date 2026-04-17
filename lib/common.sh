#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${BEDOLAGA_INSTALLER_COMMON_LOADED:-}" ]]; then
  return 0
fi
BEDOLAGA_INSTALLER_COMMON_LOADED=1

INSTALLER_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER_STATE_DIR="$INSTALLER_ROOT/state"
INSTALLER_TEMPLATES_DIR="$INSTALLER_ROOT/templates"
INSTALLER_EXAMPLES_DIR="$INSTALLER_ROOT/examples"
mkdir -p "$INSTALLER_STATE_DIR"

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_RED='\033[31m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_BLUE='\033[34m'
C_MAGENTA='\033[35m'
C_CYAN='\033[36m'

print_banner() {
  cat <<'EOF'
╭──────────────────────────────────────────────────────────────────────╮
│                    ⚡ УСТАНОВЩИК BEDOLAGA                           │
│                Бот • Кабина • Полная сборка                         │
╰──────────────────────────────────────────────────────────────────────╯
EOF
}

hr() {
  printf "%b──────────────────────────────────────────────────────────────────────%b\n" "$C_DIM" "$C_RESET"
}

clear_screen() {
  clear 2>/dev/null || true
}

print_kv() {
  local key="$1"
  local value="$2"
  printf "%b%-24s%b %s\n" "$C_DIM" "$key:" "$C_RESET" "$value"
}

print_note() {
  printf "%b%s%b\n" "$C_DIM" "$*" "$C_RESET"
}

print_card() {
  local title="$1"
  shift || true
  printf "%b╭─ %s%b\n" "$C_BOLD$C_CYAN" "$title" "$C_RESET"
  while (($#)); do
    printf "│ %s\n" "$1"
    shift
  done
  printf "%b╰────────────────────────────────────────────────────────────────────%b\n" "$C_DIM" "$C_RESET"
}

menu_item() {
  local index="$1"
  local title="$2"
  local desc="$3"
  printf "%b  %s)%b %s\n" "$C_BOLD$C_CYAN" "$index" "$C_RESET" "$title"
  printf "     %b%s%b\n" "$C_DIM" "$desc" "$C_RESET"
}

choose_install_dir() {
  local message="$1"
  local recommended="$2"
  local root_variant="$3"
  local custom=""
  local choice

  printf "%s\n" "$message" >&2
  printf "  1) %s %b(рекомендуется)%b\n" "$recommended" "$C_DIM" "$C_RESET" >&2
  printf "  2) %s\n" "$root_variant" >&2
  printf "  3) Указать свой путь\n" >&2

  while true; do
    if ! read_input choice "Выбор [1]: "; then
      choice="1"
    fi
    choice="${choice:-1}"
    case "$choice" in
      1) printf '%s' "$recommended"; return 0 ;;
      2) printf '%s' "$root_variant"; return 0 ;;
      3)
        custom="$(prompt 'Введи полный путь')"
        if [[ -n "$custom" ]]; then
          printf '%s' "$custom"
          return 0
        fi
        warn "Путь не должен быть пустым" >&2
        ;;
      *) warn "Введи 1, 2 или 3" >&2 ;;
    esac
  done
}

log()    { printf "%bℹ%b  %s\n" "$C_BLUE" "$C_RESET" "$*"; }
warn()   { printf "%b⚠%b  %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
error()  { printf "%b✖%b  %s\n" "$C_RED" "$C_RESET" "$*"; }
ok()     { printf "%b✔%b  %s\n" "$C_GREEN" "$C_RESET" "$*"; }
section(){ printf "\n%b▶ %s%b\n" "$C_BOLD$C_CYAN" "$*" "$C_RESET"; }

ensure_bash_version() {
  if (( BASH_VERSINFO[0] < 4 )); then
    error "Bash 4+ required"
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_commands() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    command_exists "$cmd" || missing+=("$cmd")
  done
  if ((${#missing[@]} > 0)); then
    error "Missing required commands: ${missing[*]}"
    return 1
  fi
}

is_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

random_hex() {
  local len="${1:-32}"
  if command_exists openssl; then
    openssl rand -hex "$len"
  else
    head -c "$len" /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

read_input() {
  local __var_name="$1"
  local __prompt="$2"
  local __value=""
  if ! read -r -p "$__prompt" __value; then
    printf -v "$__var_name" '%s' ""
    return 1
  fi
  printf -v "$__var_name" '%s' "$__value"
}

read_secret_input() {
  local __var_name="$1"
  local __prompt="$2"
  local __value=""
  if ! read -r -s -p "$__prompt" __value; then
    printf '\n' >&2
    printf -v "$__var_name" '%s' ""
    return 1
  fi
  printf '\n' >&2
  printf -v "$__var_name" '%s' "$__value"
}

prompt() {
  local message="$1"
  local default="${2:-}"
  local result=""
  if [[ -n "$default" ]]; then
    if ! read_input result "$message [$default]: "; then
      result=""
    fi
    printf '%s' "${result:-$default}"
  else
    if ! read_input result "$message: "; then
      result=""
    fi
    printf '%s' "$result"
  fi
}

prompt_secret() {
  local message="$1"
  local result=""
  if ! read_secret_input result "$message: "; then
    result=""
  fi
  printf '%s' "$result"
}

choose_option() {
  local message="$1"
  local default="$2"
  shift 2
  local options=("$@")
  local i choice selected

  printf "%s\n" "$message" >&2
  for ((i=0; i<${#options[@]}; i++)); do
    printf "  %d) %s\n" "$((i+1))" "${options[$i]}" >&2
  done

  while true; do
    if ! read_input choice "Выбор [$default]: "; then
      choice="$default"
    fi
    choice="${choice:-$default}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      selected="${options[$((choice-1))]}"
      printf '%s' "$selected"
      return 0
    fi
    warn "Введи номер варианта: 1-${#options[@]}" >&2
  done
}

confirm() {
  local message="$1"
  local answer=""
  if [[ "${INSTALLER_ASSUME_YES:-}" =~ ^(1|true|yes|on)$ ]]; then
    ok "$message -> yes (INSTALLER_ASSUME_YES)"
    return 0
  fi
  if ! read_input answer "$message [y/N]: "; then
    return 1
  fi
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

write_state_var() {
  local key="$1"
  local value="$2"
  printf '%s=%q\n' "$key" "$value" >> "$INSTALLER_STATE_DIR/session.env"
}

reset_state() {
  : > "$INSTALLER_STATE_DIR/session.env"
}

load_state() {
  if [[ -f "$INSTALLER_STATE_DIR/session.env" ]]; then
    # shellcheck disable=SC1090
    source "$INSTALLER_STATE_DIR/session.env"
  fi
}

slugify() {
  tr '[:upper:]' '[:lower:]' <<<"$1" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

detect_existing_remnawave_root() {
  local candidate
  for candidate in \
    /opt/remnawave \
    /opt/remnawave-panel \
    /opt/remnawave-panel-frontend \
    /opt/remnawave-backend
  do
    [[ -d "$candidate" ]] && {
      printf '%s\n' "$candidate"
      return 0
    }
  done
  return 1
}

render_template() {
  local template="$1"
  local destination="$2"
  envsubst < "$template" > "$destination"
}

has_docker_compose_plugin() {
  docker compose version >/dev/null 2>&1
}

has_docker_compose_legacy() {
  command_exists docker-compose
}

compose_cmd() {
  if has_docker_compose_plugin; then
    printf '%s\n' "docker compose"
    return 0
  fi
  if has_docker_compose_legacy; then
    printf '%s\n' "docker-compose"
    return 0
  fi
  return 1
}

compose_run() {
  local compose
  compose="$(compose_cmd)" || {
    error "Neither 'docker compose' nor 'docker-compose' is available"
    return 1
  }
  if [[ "$compose" == "docker compose" ]]; then
    DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose "$@"
  else
    DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose "$@"
  fi
}

is_integer() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

validate_tcp_port() {
  local port="${1:-}"
  is_integer "$port" || return 1
  (( port >= 1 && port <= 65535 ))
}

port_listener_summary() {
  local port="$1"
  ss -ltnp "( sport = :$port )" 2>/dev/null | tail -n +2 || true
}

is_port_in_use() {
  local port="$1"
  [[ -n "$(port_listener_summary "$port")" ]]
}

next_free_tcp_port() {
  local start="${1:-1024}"
  local end="${2:-65535}"
  local port
  for ((port=start; port<=end; port++)); do
    if ! is_port_in_use "$port"; then
      printf '%s\n' "$port"
      return 0
    fi
  done
  return 1
}

preferred_or_free_tcp_port() {
  local preferred="${1:-}"
  local start="${2:-1024}"
  local end="${3:-65535}"

  if validate_tcp_port "$preferred" && ! is_port_in_use "$preferred"; then
    printf '%s\n' "$preferred"
    return 0
  fi

  next_free_tcp_port "$start" "$end"
}
