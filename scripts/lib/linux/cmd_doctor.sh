#!/usr/bin/env bash

dot_cmd_doctor() {
	dot_platform_require "linux" || return 1

	info "Checking system status..."
	echo ""

	echo "  Platform: $DOT_PLATFORM"

	# Shell
	local shell_ok="no"
	[[ "$SHELL" == */zsh ]] && shell_ok="yes"
	echo "  Shell (zsh): $shell_ok ($SHELL)"

	# Services
	for svc in sshd firewalld tailscaled fail2ban chronyd opensnitch; do
		local status
		status=$(systemctl is-active "$svc" 2>/dev/null || echo "not found")
		echo "  Service ($svc): $status"
	done

	# SELinux
	echo "  SELinux: $(getenforce 2>/dev/null || echo 'unknown')"

	# DNS
	local dns
	dns=$(resolvectl status 2>/dev/null | grep "Current DNS Server" | head -1 | awk '{print $NF}')
	echo "  DNS: ${dns:-unknown}"

	# Tools
	for tool in sway ghostty starship nvim tmux bat eza zoxide fzf btop yt-dlp gallery-dl; do
		if command -v "$tool" >/dev/null 2>&1; then
			echo "  Tool ($tool): installed"
		else
			echo "  Tool ($tool): MISSING"
		fi
	done

	# SSH
	if [[ -f "$HOME/.ssh/config" ]]; then
		echo "  SSH config: present"
	else
		echo "  SSH config: MISSING (run: dot ssh configure)"
	fi

	# Git
	local git_name
	git_name="$(git config --global --get user.name 2>/dev/null || true)"
	echo "  Git user.name: ${git_name:-<unset>}"

	echo ""
	info "Done."
}
