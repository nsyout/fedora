#!/usr/bin/env bash

dot_cmd_init() {
	local assume_yes=false
	local dry_run=false
	local disable_firefox=false
	local disable_git=false
	local explicit_profile=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--yes)
			assume_yes=true
			;;
		--dry-run)
			dry_run=true
			;;
		--no-firefox)
			disable_firefox=true
			;;
		--no-git)
			disable_git=true
			;;
		--profile)
			shift
			explicit_profile="${1:-}"
			;;
		-h | --help)
			cat <<'EOF'
Usage: dot init [options]

Options:
  --profile <base|personal>
  --yes
  --dry-run
  --no-firefox
  --no-git
EOF
			return 0
			;;
		*)
			error "Unknown option for dot init: $1"
			return 1
			;;
		esac
		shift
	done

	local profile
	if [[ -n "$explicit_profile" ]]; then
		if ! dot_profile_is_valid "$explicit_profile"; then
			error "Invalid profile '$explicit_profile'. Use: base, personal"
			return 1
		fi
		profile="$explicit_profile"
	else
		profile="$(dot_profile_get)"
	fi

	local backup_dir
	backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

	backup_configs() {
		step "Backing up existing configurations"

		local files_to_backup=(
			"$HOME/.zshrc"
			"$HOME/.zshenv"
			"$HOME/.bashrc"
			"$HOME/.bash_profile"
			"$HOME/.gitconfig"
		)

		local backed_up=0
		local file
		for file in "${files_to_backup[@]}"; do
			if [[ -e "$file" ]] && [[ ! -L "$file" ]]; then
				mkdir -p "$backup_dir"
				cp -r "$file" "$backup_dir/" 2>/dev/null || true
				info "Backed up: $(basename "$file")"
				((backed_up++))
			fi
		done

		if [[ $backed_up -gt 0 ]]; then
			info "Backed up $backed_up items to $backup_dir"
		else
			info "No existing configurations to backup"
		fi
	}

	configure_shell() {
		step "Configuring shell"

		if [[ "$SHELL" != *"zsh"* ]]; then
			info "Setting Zsh as default shell..."
			local zsh_path
			zsh_path="$(command -v zsh)"

			if [[ -n "$zsh_path" ]] && ! grep -q "$zsh_path" /etc/shells; then
				echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
			fi

			chsh -s "$zsh_path" || warn "Failed to set Zsh as default shell"
		else
			info "Zsh is already the default shell"
		fi
	}

	configure_git() {
		step "Configuring Git"

		if [[ "$disable_git" == "true" ]]; then
			info "Skipping Git configuration (--no-git)"
			return 0
		fi

		if [[ "$assume_yes" == "true" ]]; then
			info "Skipping interactive Git prompts (--yes)"
			return 0
		fi

		echo "Leave empty to skip git configuration."
		read -r -p "Git user name: " git_name
		if [[ -z "$git_name" ]]; then
			info "Skipping git configuration"
			return 0
		fi

		read -r -p "Git email: " git_email
		dot_git_setup --name "$git_name" --email "$git_email" --default-branch main --yes
		info "Git configured"
	}

	configure_ssh() {
		step "Configuring SSH"

		if [[ "$assume_yes" == "true" ]]; then
			dot_ssh_configure --profile "$profile" --yes
		else
			dot_ssh_configure --profile "$profile"
		fi
	}

	setup_firefox() {
		if [[ "$disable_firefox" == "true" ]]; then
			info "Skipping Firefox setup (--no-firefox)"
			return 0
		fi

		step "Setting up Firefox configuration"

		if ! command_exists firefox; then
			warn "Firefox not installed, skipping"
			return 0
		fi

		if [[ "$assume_yes" == "true" ]]; then
			dot_cmd_firefox_sync --yes
		else
			dot_cmd_firefox_sync
		fi
	}

	post_install() {
		step "Running post-installation tasks"

		if command_exists tmux; then
			info "Setting up tmux plugin manager..."
			local tpm_dir="$HOME/.config/tmux/plugins/tpm"
			if [[ ! -d "$tpm_dir" ]]; then
				mkdir -p "$HOME/.config/tmux/plugins"
				if ! GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir" 2>/dev/null; then
					warn "Failed to clone TPM"
				fi
			else
				info "TPM already installed"
			fi
		fi

		if command_exists fzf; then
			info "FZF installed"
		else
			warn "FZF not installed (dnf install fzf)"
		fi

		info "Syncing wallpaper repository..."
		if dot_wallpaper_sync; then
			info "Setting desktop wallpaper..."
			dot_wallpaper_set || warn "Failed to set wallpaper"
		else
			warn "Failed to sync wallpaper repository; skipping wallpaper setup"
		fi

		# Install fonts for personal profile
		if [[ "$profile" == "personal" ]]; then
			install_fonts
		fi
	}

	install_fonts() {
		step "Installing personal fonts"
		local fonts_repo="git@github.com:nsyout/system-fonts.git"
		local fonts_dir="$HOME/projects/personal/system-fonts"

		if [[ -d "$fonts_dir" ]]; then
			info "Updating fonts repository..."
			git -C "$fonts_dir" pull || warn "Failed to update fonts repository"
		else
			info "Cloning fonts repository..."
			git clone "$fonts_repo" "$fonts_dir" || {
				warn "Unable to clone fonts repository, skipping"
				return 0
			}
		fi

		mkdir -p "$HOME/.local/share/fonts"
		find "$fonts_dir" -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.TTF' -o -name '*.OTF' \) -exec cp -f {} "$HOME/.local/share/fonts/" \; 2>/dev/null || true
		fc-cache -f 2>/dev/null || true
		info "Fonts installation complete"
	}

	cat <<EOF
╔══════════════════════════════════════════╗
║             DOT INIT                     ║
╚══════════════════════════════════════════╝
EOF

	info "Using profile: $profile"

	if [[ "$dry_run" == "true" ]]; then
		step "Dry run"
		info "Would back up existing configs"
		info "Would stow profile packages:"
		dot_stow_profile_packages "$profile" | while IFS= read -r pkg; do
			info "  - $pkg"
		done
		[[ "$disable_firefox" == "true" ]] || info "Would run Firefox setup"
		[[ "$disable_git" == "true" ]] || info "Would offer Git configuration"
		info "Would configure SSH"
		info "Would run post-install tasks"
		return 0
	fi

	backup_configs
	cmd_repos
	dot_packages_sync "$profile"
	dot_stow_apply "$profile" "$assume_yes"
	configure_shell
	configure_git
	configure_ssh
	setup_firefox
	post_install

	echo
	printf "%b╔══════════════════════════════════════════╗%b\n" "$COLOR_GREEN" "$COLOR_RESET"
	printf "%b║     INITIALIZATION COMPLETE!             ║%b\n" "$COLOR_GREEN" "$COLOR_RESET"
	printf "%b╚══════════════════════════════════════════╝%b\n" "$COLOR_GREEN" "$COLOR_RESET"
	if [[ -d "$backup_dir" ]]; then
		info "Backup of old configurations saved to: $backup_dir"
	fi
}
