#!/bin/bash

# Icons (nerd font codepoints)
icon_net=$'\uf0ac'
icon_warn=$'\uf071'

# Gather local network info
default_iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
local_ip=$(ip -4 addr show "$default_iface" 2>/dev/null | awk '/inet /{print $2; exit}')
gateway=$(ip route show default 2>/dev/null | awk '{print $3; exit}')

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
tooltip="${default_iface:-no interface}"
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
elif [ "$ts_state" = "connected" ]; then
    icon="$icon_net"
    class="connected"
else
    icon="$icon_net"
    class="degraded"
fi

jq -cn --arg text "$icon" --arg tooltip "$tooltip" --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
