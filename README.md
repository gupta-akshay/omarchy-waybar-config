# omarchy-waybar-config

This is my personal Waybar config for [Omarchy](https://omarchy.org/), built on top of the excellent HANCORE theme pack (details [here](https://github.com/HANCORE-linux/waybar-themes)).

![Waybar preview](./image.png)

## Requirements

This setup assumes the following tools are already available:

- Waybar (with the Hyprland modules enabled) and Hyprland itself.
- `cava` + `libcava` (used by `cava.sh` for the audio visualizer).
- `wttrbar` for the weather module output.
- `waybar-module-pacman-updates` for the pacman update indicator.
- `bc` (used by `net_speed.sh` for network speed calculations).
- `lvsk-calendar` for the calendar module.
- `ghostty`, `btop`, `wiremix`, and other Omarchy helper commands (`omarchy-*`, `impala`) that are referenced for click actions. Replace or remove these bindings if you are not on Omarchy.
- JetBrainsMono Nerd Font (Propo variant) and the Omarchy theme assets at `~/.config/omarchy/current/theme/waybar.css`, which `style.css` imports.

## Installation

### Automated (install.sh)

```bash
git clone https://github.com/gupta-akshay/omarchy-waybar-config
cd omarchy-waybar-config
./install.sh
```

If you see a permission error, run `chmod +x install.sh` (or use `bash install.sh`). The script installs/updates the required AUR packages via `yay`, backs up your existing `~/.config/waybar` directory, copies only the needed files (`config.jsonc`, `style.css`, `cava.sh`, `net_speed.sh`) into place, and makes the scripts executable. Pass `--skip-packages` if you have already installed the dependencies or want to handle them yourself, and use `--waybar-dir` to target a non-standard location.

Make sure to update your location in `custom/weather` block in your `config.jsonc` file.

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
   cp /tmp/wbr/{config.jsonc,style.css,cava.sh,net_speed.sh} ~/.config/waybar/
   rm -rf /tmp/wbr
   ```

4. Ensure the scripts are executable:

   ```bash
   chmod +x ~/.config/waybar/cava.sh
   chmod +x ~/.config/waybar/net_speed.sh
   ```

5. Update the weather location (currently set to Hildesheim) and adjust the Omarchy-specific helper commands in `config.jsonc` if you are on a different setup, then restart Waybar (e.g. `omarchy-restart-waybar`).

## What's included

- `config.jsonc` – Waybar module definitions, click actions, and custom modules (Omarchy launcher, weather, pacman updates, CAVA, network speed, calendar).
- `style.css` – Styling that imports the Omarchy theme palette and applies the HANCORE-inspired layout tweaks.
- `cava.sh` – Lightweight wrapper that streams unicode bars from CAVA for the `custom/cava` module and hides the visualizer during silence.
- `net_speed.sh` – Script that calculates and displays network upload/download speeds in Mbps for the `custom/netspeed` module.

Feel free to fork and adapt bindings, fonts, or modules to suit your setup. If you run into missing binaries, double-check the Requirements section or swap the commands for equivalents on your system.
