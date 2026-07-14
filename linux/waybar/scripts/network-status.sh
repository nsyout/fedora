#!/bin/bash

# Icons (nerd font)
icon_wifi="󰖩"
icon_eth="󰈀"
icon_warn="󰀦"

# Gather local network info
default_iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
local_ip=$(ip -4 addr show "$default_iface" 2>/dev/null | awk '/inet /{print $2; exit}')
gateway=$(ip route show default 2>/dev/null | awk '{print $3; exit}')

# Detect wired vs wifi
iface_type="unknown"
if [ -n "$default_iface" ]; then
    if [ -d "/sys/class/net/$default_iface/wireless" ]; then
        iface_type="wifi"
        ssid=$(iw dev "$default_iface" info 2>/dev/null | awk '/ssid/{print $2}' || echo "")
        # Try iw first (works on modern drivers), fall back to /proc/net/wireless
        signal_dbm=$(iw dev "$default_iface" station dump 2>/dev/null | awk '/signal:/{print $2; exit}')
        if [ -n "$signal_dbm" ]; then
            # Convert dBm to percentage (rough: -30=100%, -90=0%)
            signal=$(( (signal_dbm + 90) * 100 / 60 ))
            [ "$signal" -gt 100 ] && signal=100
            [ "$signal" -lt 0 ] && signal=0
        else
            signal=$(awk 'NR==3{print int($3 * 100 / 70)}' /proc/net/wireless 2>/dev/null || echo "")
        fi
    else
        iface_type="wired"
    fi
fi

# Gather tailscale info
ts_status=$(tailscale status --json 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$ts_status" ]; then
    ts_ip=$(echo "$ts_status" | jq -r '.Self.TailscaleIPs[0] // empty')
    ts_name=$(echo "$ts_status" | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
    ts_backend=$(echo "$ts_status" | jq -r '.BackendState // empty')

    case "$ts_backend" in
        Running) ts_state="connected" ;;
        Stopped) ts_state="stopped" ;;
        *)       ts_state="$ts_backend" ;;
    esac
else
    ts_state="unavailable"
fi

# Build tooltip
NL=$'\n'
tooltip="${default_iface:-no interface} ($iface_type)"
[ "$iface_type" = "wifi" ] && {
    [ -n "$ssid" ] && tooltip+="${NL}ssid: $ssid"
    [ -n "$signal" ] && tooltip+="${NL}signal: ${signal}%"
}
tooltip+="${NL}${local_ip:-no ip}"
[ -n "$gateway" ] && tooltip+="${NL}gateway: $gateway"
tooltip+="${NL}"
tooltip+="${NL}tailscale: $ts_state"
[ "$ts_state" = "connected" ] && {
    tooltip+="${NL}$ts_ip"
    [ -n "$ts_name" ] && tooltip+="${NL}$ts_name"
}

# Determine icon and class
if [ -z "$default_iface" ]; then
    icon="$icon_warn"
    class="disconnected"
else
    if [ "$iface_type" = "wifi" ]; then
        icon="$icon_wifi"
    else
        icon="$icon_eth"
    fi
    if [ "$ts_state" = "connected" ]; then
        class="connected"
    else
        class="degraded"
    fi
fi

jq -cn --arg text "$icon" --arg tooltip "$tooltip" --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
