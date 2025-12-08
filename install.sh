#!/usr/bin/env bash
set -euo pipefail

PACKAGES=(cava libcava wttrbar waybar-module-pacman-updates bc lvsk-calendar)
FILES=(config.jsonc style.css cava.sh net_speed.sh)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="${HOME}/.config/waybar"
SKIP_PACKAGES=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --skip-packages        Skip package installation (assumes deps are present)
  --waybar-dir <path>    Override Waybar config destination (default: ~/.config/waybar)
  -h, --help             Show this message
EOF
}

log() {
  printf '==> %s\n' "$1"
}

error() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-packages)
      SKIP_PACKAGES=true
      ;;
    --waybar-dir)
      shift
      [[ $# -gt 0 ]] || error "--waybar-dir expects a path"
      WAYBAR_DIR="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      error "Unknown option: $1"
      ;;
  esac
  shift
done

WAYBAR_DIR="${WAYBAR_DIR/#\~/$HOME}"

install_packages() {
  if [[ "$SKIP_PACKAGES" == "true" ]]; then
    log "Skipping package installation"
    return
  fi

  command -v yay >/dev/null 2>&1 || error "yay is required to install dependencies. Install yay or rerun with --skip-packages."
  log "Installing/updating packages: ${PACKAGES[*]}"
  yay -S --needed "${PACKAGES[@]}"
}

backup_existing() {
  if [[ -d "$WAYBAR_DIR" || -L "$WAYBAR_DIR" ]]; then
    local backup="${WAYBAR_DIR}.bak.$(date +%s)"
    log "Backing up existing Waybar config to $backup"
    mv "$WAYBAR_DIR" "$backup"
  fi
}

copy_config() {
  log "Deploying config to $WAYBAR_DIR"
  mkdir -p "$WAYBAR_DIR"
  for file in "${FILES[@]}"; do
    local src="$REPO_DIR/$file"
    [[ -e "$src" ]] || error "Missing required file: $file"
    cp -a "$src" "$WAYBAR_DIR/"
  done

  chmod +x "$WAYBAR_DIR/cava.sh"
  chmod +x "$WAYBAR_DIR/net_speed.sh"
}

main() {
  install_packages
  backup_existing
  copy_config
  log "All done! Restart Waybar (or run omarchy-restart-waybar) to apply the theme."
}

main "$@"

