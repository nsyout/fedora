#!/bin/bash
# System menu for rofi — theme switching, power, and system controls

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

# Menu entries (icon + label + action)
entries=(
	"  Theme"
	"  Lock"
	"  Logout"
	"  Suspend"
	"  Reboot"
	"  Shutdown"
	"  Reload Sway"
	"  Edit Dotfiles"
)

chosen=$(printf '%s\n' "${entries[@]}" | rofi -dmenu -p "System" -theme ~/.config/rofi/theme.rasi -i)
[[ -z "$chosen" ]] && exit 0

case "$chosen" in
*"Theme"*)
	# Show theme picker
	current=$(cat "$DOTFILES/config/theme/current-theme")
	themes=$(find "$DOTFILES/themes/" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort)
	selected=$(echo "$themes" | rofi -dmenu -p "Theme (current: $current)" -theme ~/.config/rofi/theme.rasi -i)
	[[ -n "$selected" ]] && "$DOTFILES/dot" theme set "$selected"
	;;
*"Lock"*)
	loginctl lock-session
	;;
*"Logout"*)
	swaymsg exit
	;;
*"Suspend"*)
	systemctl suspend
	;;
*"Reboot"*)
	systemctl reboot
	;;
*"Shutdown"*)
	systemctl poweroff
	;;
*"Reload Sway"*)
	swaymsg reload
	;;
*"Edit Dotfiles"*)
	ghostty -e "${EDITOR:-nvim}" "$DOTFILES"
	;;
esac
