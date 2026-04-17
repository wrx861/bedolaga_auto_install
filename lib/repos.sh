#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BEDOLAGA_BOT_REPO_DEFAULT="https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot.git"
BEDOLAGA_CABINET_REPO_DEFAULT="https://github.com/BEDOLAGA-DEV/bedolaga-cabinet.git"

clone_or_update_repo() {
  local repo_url="$1"
  local target_dir="$2"
  local branch="${3:-main}"

  if [[ -d "$target_dir/.git" ]]; then
    log "Updating repo: $target_dir"
    git -C "$target_dir" fetch origin "$branch"
    git -C "$target_dir" checkout "$branch"
    git -C "$target_dir" pull --ff-only origin "$branch"
    return 0
  fi

  mkdir -p "$target_dir"

  if [[ -n "$(find "$target_dir" -mindepth 1 -maxdepth 1 -not -name generated -not -name bundles -not -name INSTALLER_NEXT_STEPS.txt 2>/dev/null | head -n 1)" ]]; then
    error "Target dir is not empty and contains non-installer files: $target_dir"
    return 1
  fi

  if [[ -n "$(find "$target_dir" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]]; then
    log "Cloning repo into existing installer-prepared dir: $target_dir"
    local tmpdir
    tmpdir="$(mktemp -d)"
    git clone --branch "$branch" "$repo_url" "$tmpdir/repo"
    cp -a "$tmpdir/repo"/. "$target_dir/"
    rm -rf "$tmpdir"
  else
    log "Cloning repo: $repo_url -> $target_dir"
    git clone --branch "$branch" "$repo_url" "$target_dir"
  fi
}

materialize_source_repos() {
  load_state
  section "Fetching source repos"

  local bot_repo="${BEDOLAGA_BOT_REPO_URL:-$BEDOLAGA_BOT_REPO_DEFAULT}"
  local cabinet_repo="${BEDOLAGA_CABINET_REPO_URL:-$BEDOLAGA_CABINET_REPO_DEFAULT}"
  local branch="${BEDOLAGA_STACK_BRANCH:-main}"

  case "${INSTALL_MODE:-}" in
    bot-only)
      clone_or_update_repo "$bot_repo" "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}" "$branch"
      ;;
    cabinet-only)
      clone_or_update_repo "$cabinet_repo" "${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}" "$branch"
      ;;
    bot+cabinet)
      clone_or_update_repo "$bot_repo" "${BOT_INSTALL_DIR:-/opt/remnawave-bedolaga-telegram-bot}" "$branch"
      clone_or_update_repo "$cabinet_repo" "${CABINET_INSTALL_DIR:-/opt/bedolaga-cabinet}" "$branch"
      ;;
    *)
      error "INSTALL_MODE is not set"
      return 1
      ;;
  esac

  ok "Source repos materialized into separate install dirs"
}
