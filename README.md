# omarchy-waybar-config

This is my personal Waybar config for [Omarchy](https://omarchy.org/), built on top of the excellent HANCORE theme pack (details [here](https://github.com/HANCORE-linux/waybar-themes)).

![Waybar preview](./image.png)

## Requirements

This setup assumes the following tools are already available:

- Waybar (with the Hyprland modules enabled) and Hyprland itself.
- `cava` + `libcava` (used by `scripts/cava.sh` for the audio visualizer).
- `wttrbar` for the weather module output.
- `waybar-module-pacman-updates` for the pacman update indicator.
- `bc` (used by `scripts/net_speed.sh` for network speed calculations).
- `lvsk-calendar` for the calendar module.
- `playerctl` for media player control (MPRIS module).
- `nvidia-smi` (from `nvidia-utils`) **only if you enable** the optional `custom/gpu` module (NVIDIA only for now).
- `ghostty`, `btop`, `wiremix`, `thunar`, `powerprofilesctl`, and other Omarchy helper commands (`omarchy-*`, `impala`) that are referenced for click actions. Replace or remove these bindings if you are not on Omarchy.
- JetBrainsMono Nerd Font (Propo variant) and the Omarchy theme assets at `~/.config/omarchy/current/theme/waybar.css`, which `style.css` imports.

**Note:** The temperature module is configured for specific hardware paths (`/sys/class/hwmon/hwmon3/temp2_input` and thermal zone 2). You may need to adjust these paths in `config.jsonc` to match your system's hardware monitoring setup.

## Installation

### Automated (install.sh)

```bash
git clone https://github.com/gupta-akshay/omarchy-waybar-config
cd omarchy-waybar-config
./install.sh
```

If you see a permission error, run `chmod +x install.sh` (or use `bash install.sh`). The script installs/updates the required AUR packages via `yay`, backs up your existing `~/.config/waybar` directory, and copies the config (`config.jsonc`, `modules/`, `scripts/`, `style.css`) into place.

During installation, you’ll be prompted to select optional modules (you can choose one, many, or none). The installer then generates `modules/layout.jsonc` with your selections while keeping the core modules always present. If you enable `custom/weather`, you’ll also be prompted for a weather location (unless provided via `--location`).

Pass `--skip-packages` if you have already installed the dependencies or want to handle them yourself, use `--waybar-dir` to target a non-standard location, and pass `--location "Your City"` to set the weather location non-interactively.

### Manual (if you prefer to do it yourself)

1. Install the required packages:

   ```bash
   yay -S cava libcava wttrbar waybar-module-pacman-updates bc lvsk-calendar
   ```

2. Back up your existing Waybar config (if present):

   ```bash
   mv ~/.config/waybar ~/.config/waybar.bak
   ```

3. Clone this repo somewhere temporary and copy the required files into your Waybar directory:

   ```bash
   git clone https://github.com/gupta-akshay/omarchy-waybar-config /tmp/wbr
   mkdir -p ~/.config/waybar
   cp -a /tmp/wbr/{config.jsonc,style.css,modules,scripts} ~/.config/waybar/
   rm -rf /tmp/wbr
   ```

4. Ensure the scripts are executable:

   ```bash
   chmod +x ~/.config/waybar/scripts/cava.sh
   chmod +x ~/.config/waybar/scripts/net_speed.sh
   chmod +x ~/.config/waybar/scripts/waybar-gpu.sh
   ```

5. Adjust the temperature module hardware paths if needed (see Requirements), and adjust the Omarchy-specific helper commands in the `modules/*.jsonc` files if you are on a different setup.

   To enable/disable modules manually, edit `modules/layout.jsonc` (core modules should remain present).

   Then restart Waybar (e.g. `omarchy-restart-waybar`).

## What's included

- `config.jsonc` + `modules/*.jsonc` – Waybar module definitions, click actions, and custom modules:
  - **Core layout (always enabled):**
    - **Left:** Omarchy launcher, Hyprland workspaces, active window
    - **Center:** Clock, pacman updates, Omarchy update checker
    - **Right:** Tray (with expander), network, CPU, audio, battery
  - **Optional modules (select during install or edit `modules/layout.jsonc`):**
    - **Left:** CAVA audio visualizer (`custom/cava`), MPRIS media player (`mpris`)
    - **Center:** Calendar (`custom/calendar`), Weather (`custom/weather`), Network speed (`custom/netspeed`)
    - **Right:** Idle inhibitor, temperature, disk, memory, GPU (`custom/gpu`, **NVIDIA only for now**)
  - Includes Bluetooth module within the tray expander group
- `style.css` – Styling that imports the Omarchy theme palette and applies the HANCORE-inspired layout tweaks with hover effects, animations, and color-coded states (critical battery/disk/temperature warnings).
- `scripts/cava.sh` – Lightweight wrapper that streams unicode bars from CAVA for the `custom/cava` module and automatically hides the visualizer during 2+ seconds of silence.
- `scripts/net_speed.sh` – Script that calculates and displays network upload/download speeds in Mbps for the `custom/netspeed` module, preferring non-tunnel interfaces.
- `scripts/waybar-gpu.sh` – Script backing the optional `custom/gpu` module (**NVIDIA only for now**, requires `nvidia-smi`).

Feel free to fork and adapt bindings, fonts, or modules to suit your setup. If you run into missing binaries, double-check the Requirements section or swap the commands for equivalents on your system.
