#!/bin/bash

# Get default route interfaces, preferring non-tunnel interfaces
# First try to find a non-tunnel interface (exclude tun*, tap*, vpn*, etc.)
INTERFACE=$(ip route | grep '^default' | awk '{print $5}' | grep -vE '^(tun|tap|vpn|ppp|wg)' | head -n 1)

# If no non-tunnel interface found, fall back to the first default route
if [[ -z "$INTERFACE" ]]; then
  INTERFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n 1)
fi

# If still no interface found, exit gracefully
if [[ -z "$INTERFACE" ]] || [[ ! -d "/sys/class/net/$INTERFACE" ]]; then
  echo "⇣ 0.00 Mbps ⇡ 0.00 Mbps"
  exit 0
fi

# Validate that statistics files exist
if [[ ! -f "/sys/class/net/$INTERFACE/statistics/rx_bytes" ]] || \
   [[ ! -f "/sys/class/net/$INTERFACE/statistics/tx_bytes" ]]; then
  echo "⇣ 0.00 Mbps ⇡ 0.00 Mbps"
  exit 0
fi

RX_PREV=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
TX_PREV=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
sleep 1
RX_CURR=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
TX_CURR=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)

RX_DIFF=$((RX_CURR - RX_PREV))
TX_DIFF=$((TX_CURR - TX_PREV))

# Convert to Mbps (bytes * 8 / 1_000_000)
RX_Mbps=$(echo "scale=2; $RX_DIFF * 8 / 1000000" | bc)
TX_Mbps=$(echo "scale=2; $TX_DIFF * 8 / 1000000" | bc)

echo -e "⇣ ${RX_Mbps} Mbps ⇡ ${TX_Mbps} Mbps"
