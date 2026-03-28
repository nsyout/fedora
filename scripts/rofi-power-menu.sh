#!/bin/bash
# Power menu for rofi

choice=$(printf "Lock\nLogout\nSuspend\nReboot\nShutdown" | rofi -dmenu -p "Power" -theme-str 'window {width: 250px;} listview {lines: 5;}')

case "$choice" in
Lock) loginctl lock-session ;;
Logout) swaymsg exit ;;
Suspend) systemctl suspend ;;
Reboot) systemctl reboot ;;
Shutdown) systemctl poweroff ;;
esac
