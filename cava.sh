#!/bin/bash

# Unicode bars (0–7)
bars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)

# write cava config
config_file="/tmp/waybar_cava_config"
cat > "$config_file" <<EOF
[general]
bars = 24
framerate = 60
autosens = 1

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

# kill cava when waybar kills this script
trap "kill 0" EXIT

pause_start=0

convert_to_bars() {
    IFS=';' read -ra nums <<< "$1"
    out=""
    for n in "${nums[@]}"; do
        (( n >= 0 && n <= 7 )) || n=0
        out+="${bars[$n]}"
    done
    printf '%s\n' "$out"
}

cava -p "$config_file" | \
while IFS= read -r line; do
    now=$(date +%s)

    # silence (only zeros)
    if [[ "$line" =~ ^(0;?)+$ ]]; then
        if (( pause_start == 0 )); then
            pause_start=$now
        fi

        # hide after 2 seconds of silence
        if (( now - pause_start >= 2 )); then
            echo ""
        else
            convert_to_bars "$line"
        fi

        continue
    fi

    # audio back → reset timer
    pause_start=0

    # print bars
    convert_to_bars "$line"
done
