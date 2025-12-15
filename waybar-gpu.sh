#!/usr/bin/env bash
util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
mem=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
mem_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits)
echo "{\"text\": \"󰓹 ${util}%\", \"tooltip\": \"GPU: ${gpu_name}\nUsage: ${util}%\nTemperature: ${temp}°C\nMemory: ${mem}MiB / ${mem_total}MiB\"}"
