#!/usr/bin/env bash
set -euo pipefail

PACKAGES=(cava libcava wttrbar waybar-module-pacman-updates bc lvsk-calendar)
FILES=(config.jsonc style.css modules cava.sh net_speed.sh waybar-gpu.sh)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="${HOME}/.config/waybar"
SKIP_PACKAGES=false
WEATHER_LOCATION=""
SELECTED_OPTIONAL_MODULES=()

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

contains_item() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

select_optional_modules() {
  # Optional modules (not core). Users can pick 0+.
  # Format: "<module>|<position>|<label>"
  local -a options=(
    "custom/cava|modules-left|CAVA audio visualizer"
    "mpris|modules-left|Media player (MPRIS)"
    "custom/calendar|modules-center|Calendar launcher"
    "custom/weather|modules-center|Weather (wttrbar)"
    "custom/netspeed|modules-center|Network speed"
    "idle_inhibitor|modules-right|Idle inhibitor toggle"
    "temperature|modules-right|Temperature"
    "disk|modules-right|Disk usage"
    "memory|modules-right|Memory usage"
    "custom/gpu|modules-right|GPU stats (NVIDIA only)"
  )

  # If we can't prompt (non-interactive), default to none selected.
  if [[ ! -t 0 ]]; then
    SELECTED_OPTIONAL_MODULES=()
    return 0
  fi

  printf '\n'
  printf 'Waybar optional modules\n'
  printf 'Select optional modules to enable (core modules are always included).\n'
  printf 'Enter numbers separated by spaces/commas. Empty = none. "a" = all.\n\n'

  local i=1
  local entry module position label
  for entry in "${options[@]}"; do
    IFS='|' read -r module position label <<<"$entry"
    printf '%2d) %-18s (%s) - %s\n' "$i" "$module" "$position" "$label"
    i=$((i + 1))
  done

  local input
  while true; do
    printf '\n'
    read -r -p "Selection: " input

    # none
    if [[ -z "${input}" ]]; then
      SELECTED_OPTIONAL_MODULES=()
      return 0
    fi

    # all
    if [[ "${input}" == "a" || "${input}" == "all" ]]; then
      SELECTED_OPTIONAL_MODULES=()
      for entry in "${options[@]}"; do
        IFS='|' read -r module position label <<<"$entry"
        SELECTED_OPTIONAL_MODULES+=("$module")
      done
      return 0
    fi

    # parse numbers
    input="${input//,/ }"
    local -a picked=()
    local tok
    local max=$(( ${#options[@]} ))
    local ok=true
    for tok in $input; do
      if [[ ! "$tok" =~ ^[0-9]+$ ]]; then
        ok=false
        break
      fi
      if (( tok < 1 || tok > max )); then
        ok=false
        break
      fi
      entry="${options[$((tok - 1))]}"
      IFS='|' read -r module position label <<<"$entry"
      if ! contains_item "$module" "${picked[@]}"; then
        picked+=("$module")
      fi
    done

    if [[ "$ok" == "true" ]]; then
      SELECTED_OPTIONAL_MODULES=("${picked[@]}")
      return 0
    fi

    printf 'Invalid selection. Please enter numbers between 1 and %d (e.g. "1 3 5"), empty for none, or "a" for all.\n' "$max"
  done
}

write_layout() {
  local layout_file="$WAYBAR_DIR/modules/layout.jsonc"
  mkdir -p "$(dirname "$layout_file")"

  local -a modules_left=( "custom/omarchy" "hyprland/workspaces" "hyprland/window" )
  local -a modules_center=( "clock" "custom/updatespacman" "custom/update" )
  local -a modules_right=( "group/tray-expander" "network" "cpu" "pulseaudio" "battery" )

  # Insert selected optional modules into their canonical positions.
  if contains_item "custom/cava" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    modules_left+=( "custom/cava" )
  fi
  if contains_item "mpris" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    modules_left+=( "mpris" )
  fi

  # Center: clock, (optional), updates...
  local -a center_optional=()
  if contains_item "custom/calendar" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    center_optional+=( "custom/calendar" )
  fi
  if contains_item "custom/weather" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    center_optional+=( "custom/weather" )
  fi
  if contains_item "custom/netspeed" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    center_optional+=( "custom/netspeed" )
  fi
  if (( ${#center_optional[@]} > 0 )); then
    modules_center=( "clock" "${center_optional[@]}" "custom/updatespacman" "custom/update" )
  fi

  # Right: tray-expander, (optional), then core
  local -a right_pre_network_optional=()
  local -a right_post_network_optional=()
  if contains_item "idle_inhibitor" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    right_pre_network_optional+=( "idle_inhibitor" )
  fi
  if contains_item "temperature" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    right_pre_network_optional+=( "temperature" )
  fi
  if contains_item "disk" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    right_post_network_optional+=( "disk" )
  fi
  if contains_item "memory" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    right_post_network_optional+=( "memory" )
  fi
  if contains_item "custom/gpu" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    right_post_network_optional+=( "custom/gpu" )
  fi
  if (( ${#right_pre_network_optional[@]} > 0 || ${#right_post_network_optional[@]} > 0 )); then
    modules_right=( "group/tray-expander" "${right_pre_network_optional[@]}" "network" "${right_post_network_optional[@]}" "cpu" "pulseaudio" "battery" )
  fi

  print_json_array() {
    local indent="$1"; shift
    local first=true
    local item
    for item in "$@"; do
      if [[ "$first" == "true" ]]; then
        first=false
      else
        printf ',\n'
      fi
      printf '%s"%s"' "$indent" "$item"
    done
  }

  {
    printf '{\n'
    printf '  "modules-left": [\n'
    print_json_array '    ' "${modules_left[@]}"
    printf '\n  ],\n'
    printf '  "modules-center": [\n'
    print_json_array '    ' "${modules_center[@]}"
    printf '\n  ],\n'
    printf '  "modules-right": [\n'
    print_json_array '    ' "${modules_right[@]}"
    printf '\n  ]\n'
    printf '}\n'
  } >"$layout_file"
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

  # Ensure scripts are executable (git perms may not be preserved on some setups).
  local -a script_paths=(
    "$WAYBAR_DIR/cava.sh"
    "$WAYBAR_DIR/net_speed.sh"
    "$WAYBAR_DIR/waybar-gpu.sh"
  )

  local p
  for p in "${script_paths[@]}"; do
    [[ -f "$p" ]] || continue
    chmod +x "$p" || true
  done

  if command -v stat >/dev/null 2>&1; then
    log "Script permissions:"
    for p in "${script_paths[@]}"; do
      [[ -f "$p" ]] || continue
      stat -c '%a %n' "$p" 2>/dev/null || true
    done
  fi
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
    # Write JSON so Waybar receives: wttrbar --nerd --location "{provided location}"
    # This must appear in the JSON as: \"{provided location}\"
    local exec_cmd_raw
    exec_cmd_raw="wttrbar --nerd --location \"${WEATHER_LOCATION}\""
    exec_cmd="$(json_escape "$exec_cmd_raw")"
    click_url="wttr.in/$(uri_encode "$WEATHER_LOCATION")?format=3"
  else
    exec_cmd="$(json_escape "wttrbar --nerd")"
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
  select_optional_modules
  backup_existing
  copy_config

  # Always generate layout based on core + user selection.
  write_layout

  if contains_item "custom/gpu" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    printf '\n'
    printf 'Note: custom/gpu currently only supports NVIDIA GPUs (requires nvidia-smi).\n'
  fi

  # Only prompt/configure weather if the weather module is enabled.
  if contains_item "custom/weather" "${SELECTED_OPTIONAL_MODULES[@]}"; then
    configure_weather
  fi

  # Apply changes immediately when running on Omarchy.
  if command -v omarchy-restart-waybar >/dev/null 2>&1; then
    log "Restarting Waybar (omarchy-restart-waybar)"
    omarchy-restart-waybar || true
  fi

  log "All done!"
}

main "$@"

