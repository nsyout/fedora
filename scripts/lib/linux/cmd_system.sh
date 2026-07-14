#!/usr/bin/env bash

dot_cmd_repos() {
	dot_platform_require "linux" || return 1

	info "Configuring third-party repositories..."

	# Flatpak + Flathub
	if ! command -v flatpak >/dev/null 2>&1; then
		info "Installing Flatpak..."
		sudo dnf install -y flatpak
	fi
	if ! flatpak remotes | grep -q flathub; then
		info "Adding Flathub repository..."
		flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
		info "  ADDED: Flathub"
	else
		info "  OK: Flathub"
	fi

	# RPM repos
	local repo_configs=(
		"1password:https://downloads.1password.com/linux/keys/1password.asc"
		"sublime-text:https://download.sublimetext.com/sublimehq-rpm-pub.gpg"
		"dropbox:https://linux.dropbox.com/fedora/rpm-public-key.asc"
	)

	for entry in "${repo_configs[@]}"; do
		local repo_name="${entry%%:*}"
		local gpg_url="${entry#*:}"
		local repo_file="/etc/yum.repos.d/${repo_name}.repo"

		if [[ ! -f "$repo_file" ]]; then
			if [[ -f "$DOT_PLATFORM_DIR/etc/yum.repos.d/${repo_name}.repo" ]]; then
				info "Adding ${repo_name} repository..."
				sudo rpm --import "$gpg_url" 2>/dev/null || true
				sudo cp "$DOT_PLATFORM_DIR/etc/yum.repos.d/${repo_name}.repo" "$repo_file"
				info "  ADDED: ${repo_name}"
			fi
		else
			info "  OK: ${repo_name}"
		fi
	done

	# Tailscale
	if [[ ! -f /etc/yum.repos.d/tailscale.repo ]]; then
		info "Adding Tailscale repository..."
		sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
		info "  ADDED: tailscale"
	else
		info "  OK: tailscale"
	fi

	info "Done."
}

dot_cmd_system() {
	dot_platform_require "linux" || return 1

	info "Installing system configs..."

	# Set up third-party repos first
	dot_cmd_repos

	local configs=(
		"etc/sysctl.d/90-hardening.conf:/etc/sysctl.d/90-hardening.conf"
		"etc/systemd/resolved.conf.d/quad9.conf:/etc/systemd/resolved.conf.d/quad9.conf"
		"etc/chrony.conf:/etc/chrony.conf"
		"etc/fail2ban/jail.local:/etc/fail2ban/jail.local"
		"etc/greetd/config.toml:/etc/greetd/config.toml"
		"etc/pam.d/greetd:/etc/pam.d/greetd"
		"etc/pam.d/swaylock:/etc/pam.d/swaylock"
		"etc/systemd/system/sshd.service.d/tailscale.conf:/etc/systemd/system/sshd.service.d/tailscale.conf"
		"etc/dnf/dnf.conf:/etc/dnf/dnf.conf"
		"etc/NetworkManager/conf.d/99-privacy.conf:/etc/NetworkManager/conf.d/99-privacy.conf"
		"etc/tlp.d/01-amd.conf:/etc/tlp.d/01-amd.conf"
		"etc/vconsole.conf:/etc/vconsole.conf"
	)

	for entry in "${configs[@]}"; do
		local src="${entry%%:*}"
		local dst="${entry##*:}"
		if [[ -f "$DOT_PLATFORM_DIR/$src" ]]; then
			sudo mkdir -p "$(dirname "$dst")"
			sudo cp "$DOT_PLATFORM_DIR/$src" "$dst"
			echo "  INSTALLED: $dst"
		fi
	done

	info "Enabling greetd..."
	sudo systemctl enable greetd
	sudo systemctl set-default graphical.target

	if command -v tlp >/dev/null 2>&1; then
		info "Enabling TLP..."
		sudo systemctl enable tlp
		sudo systemctl mask power-profiles-daemon 2>/dev/null || true
	fi

	info "Reloading services..."
	sudo sysctl --system >/dev/null 2>&1
	sudo systemctl daemon-reload
	sudo systemctl restart systemd-resolved
	sudo systemctl restart chronyd
	sudo systemctl restart fail2ban
	sudo systemctl restart NetworkManager

	info "Done."
}
