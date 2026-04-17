#!/usr/bin/env bash
set -euo pipefail

REPO_URL_DEFAULT="https://github.com/BEDOLAGA-DEV/bedolaga-stack-installer.git"
BRANCH_DEFAULT="main"
TARGET_DIR_DEFAULT="/opt/bedolaga-stack-installer"

REPO_URL="${BEDOLAGA_INSTALLER_REPO_URL:-$REPO_URL_DEFAULT}"
BRANCH="${BEDOLAGA_INSTALLER_BRANCH:-$BRANCH_DEFAULT}"
TARGET_DIR="${BEDOLAGA_INSTALLER_DIR:-$TARGET_DIR_DEFAULT}"

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

need git
need bash
need mktemp

if [[ -d "$TARGET_DIR/.git" ]]; then
  echo "[INFO] Updating existing installer in $TARGET_DIR"
  git -C "$TARGET_DIR" fetch origin "$BRANCH"
  git -C "$TARGET_DIR" checkout "$BRANCH"
  git -C "$TARGET_DIR" pull --ff-only origin "$BRANCH"
else
  echo "[INFO] Cloning installer to $TARGET_DIR"
  rm -rf "$TARGET_DIR"
  git clone --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"
fi

chmod +x "$TARGET_DIR/install.sh"
exec "$TARGET_DIR/install.sh"
