#!/usr/bin/env bash
set -euo pipefail

PACKAGES=(cava libcava wttrbar waybar-module-pacman-updates bc lvsk-calendar)
FILES=(config.jsonc style.css cava.sh net_speed.sh modules)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="${HOME}/.config/waybar"
SKIP_PACKAGES=false
WEATHER_LOCATION=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --skip-packages        Skip package installation (assumes deps are present)
  --waybar-dir <path>    Override Waybar config destination (default: ~/.config/waybar)
  --location <location>  Weather location for wttr (e.g. "Berlin" or "New York"). Leave empty for auto.
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
    --location)
      shift
      [[ $# -gt 0 ]] || error "--location expects a value (or pass an empty string: --location '')"
      WEATHER_LOCATION="$1"
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

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

uri_encode() {
  local s="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' "$s"
import sys
import urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
    return 0
  fi

  # Basic fallback: spaces only
  printf '%s' "$s" | sed 's/ /%20/g'
}

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

configure_weather() {
  local weather_file="$WAYBAR_DIR/modules/custom-weather.jsonc"
  mkdir -p "$(dirname "$weather_file")"

  # Prompt only if not provided via --location and we're in an interactive terminal.
  if [[ -z "${WEATHER_LOCATION}" && -t 0 ]]; then
    printf '\n'
    printf 'Waybar weather setup (wttrbar)\n'
    printf 'Enter your location (examples: "Berlin", "New York", "Tokyo").\n'
    printf 'Leave empty to let wttr auto-detect your location via IP.\n\n'
    read -r -p "Weather location: " WEATHER_LOCATION
  fi

  local exec_cmd
  local click_url

  if [[ -n "${WEATHER_LOCATION}" ]]; then
    local loc_json
    loc_json="$(json_escape "$WEATHER_LOCATION")"
    exec_cmd="wttrbar --nerd --location \"${loc_json}\""
    click_url="wttr.in/$(uri_encode "$WEATHER_LOCATION")?format=3"
  else
    exec_cmd="wttrbar --nerd"
    click_url="wttr.in?format=3"
  fi

  cat >"$weather_file" <<EOF
{
  "custom/weather": {
    "format": "{}°",
    "tooltip": true,
    "interval": 300,
    "exec": "${exec_cmd}",
    "return-type": "json",
    "on-click": "curl -s '${click_url}' | xargs -I {} notify-send 'Weather' {}"
  }
}
EOF
}

main() {
  install_packages
  backup_existing
  copy_config
  configure_weather
  log "All done! Restart Waybar (or run omarchy-restart-waybar) to apply the theme."
}

main "$@"

