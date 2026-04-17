#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"
REPO_URL_DEFAULT="https://github.com/wrx861/bedolaga_auto_install.git"
BRANCH_DEFAULT="main"
TARGET_DIR_DEFAULT="/opt/bedolaga-stack-installer"

bootstrap_and_reexec() {
  local repo_url="${BEDOLAGA_INSTALLER_REPO_URL:-$REPO_URL_DEFAULT}"
  local branch="${BEDOLAGA_INSTALLER_BRANCH:-$BRANCH_DEFAULT}"
  local target_dir="${BEDOLAGA_INSTALLER_DIR:-$TARGET_DIR_DEFAULT}"

  need git
  need bash

  if [[ -d "$target_dir/.git" ]]; then
    echo "[INFO] Updating existing installer in $target_dir"
    git -C "$target_dir" fetch origin "$branch"
    git -C "$target_dir" checkout "$branch"
    git -C "$target_dir" pull --ff-only origin "$branch"
  else
    echo "[INFO] Cloning installer to $target_dir"
    rm -rf "$target_dir"
    git clone --branch "$branch" "$repo_url" "$target_dir"
  fi

  chmod +x "$target_dir/install.sh"
  exec "$target_dir/install.sh" "$@"
}

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

if [[ ! -f "$SCRIPT_DIR/lib/common.sh" || ! -f "$SCRIPT_DIR/lib/menu.sh" ]]; then
  bootstrap_and_reexec "$@"
fi

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/menu.sh
source "$SCRIPT_DIR/lib/menu.sh"

main() {
  print_banner
  ensure_bash_version
  run_main_menu
}

main "$@"
