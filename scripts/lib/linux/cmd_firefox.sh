#!/usr/bin/env bash

dot_cmd_firefox() {
	local action="${1:-}"
	shift || true

	case "$action" in
	"" | -h | --help | help)
		cat <<'EOF'
Usage: dot firefox sync [options]

Options:
  --dry-run
  --yes
EOF
		return 0
		;;
	sync)
		dot_cmd_firefox_sync "$@"
		;;
	*)
		error "Unknown firefox action: $action"
		return 1
		;;
	esac
}

_dot_firefox_parse_extensions() {
	local conf="$1"

	while IFS= read -r line; do
		line="${line%%#*}"
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[[ -z "$line" ]] && continue

		local name ext_id addon_slug
		IFS=':' read -r name ext_id addon_slug <<<"$line"

		printf '%s:%s:%s\n' "$name" "$ext_id" "$addon_slug"
	done <"$conf"
}

_dot_firefox_install_extensions() {
	local profile_dir="$1"
	local dry_run="$2"
	local conf="$3"
	local ext_dir="$profile_dir/extensions"

	local has_extensions=false
	while IFS=':' read -r name ext_id addon_slug; do
		has_extensions=true

		if [[ "$dry_run" == "true" ]]; then
			info "  Would install: $name"
			continue
		fi

		if [[ -f "$ext_dir/${ext_id}.xpi" ]]; then
			info "  OK: $name"
			continue
		fi

		mkdir -p "$ext_dir"
		local url="https://addons.mozilla.org/firefox/downloads/latest/${addon_slug}/latest.xpi"
		if curl -fsSL "$url" -o "$ext_dir/${ext_id}.xpi"; then
			info "  Installed: $name"
		else
			warn "  Failed to download: $name ($addon_slug)"
		fi
	done < <(_dot_firefox_parse_extensions "$conf")

	if [[ "$has_extensions" == "false" ]]; then
		info "  No extensions configured in $conf"
	fi
}

dot_cmd_firefox_sync() {
	local dry_run=false
	local assume_yes=false
	local dotfiles_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"
	local firefox_config="$DOT_PLATFORM_DIR/firefox"
	local user_overrides="$firefox_config/user-overrides.js"
	local extensions_conf="$firefox_config/extensions.conf"
	# Fedora uses XDG path, other distros use ~/.mozilla
	local profiles_dir=""
	if [[ -d "$HOME/.config/mozilla/firefox" ]]; then
		profiles_dir="$HOME/.config/mozilla/firefox"
	elif [[ -d "$HOME/.mozilla/firefox" ]]; then
		profiles_dir="$HOME/.mozilla/firefox"
	fi

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			dry_run=true
			;;
		--yes)
			assume_yes=true
			;;
		-h | --help)
			cat <<'EOF'
Usage: dot firefox sync [options]

Options:
  --dry-run
  --yes
EOF
			return 0
			;;
		*)
			error "Unknown option for dot firefox sync: $1"
			return 1
			;;
		esac
		shift
	done

	if ! command_exists firefox; then
		warn "Firefox not installed, skipping"
		return 0
	fi

	if [[ ! -f "$user_overrides" ]]; then
		warn "Firefox overrides not found: $user_overrides"
		return 0
	fi

	local profile_dir=""
	if [[ -n "$profiles_dir" ]]; then
		profile_dir=$(find "$profiles_dir" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -1)
	fi

	if [[ -z "$profile_dir" ]]; then
		warn "No Firefox profile found"
		return 0
	fi

	if [[ "$dry_run" == "true" ]]; then
		step "Dry run"
		info "Would update Firefox profile: $(basename "$profile_dir")"
		info "Would download latest arkenfox user.js"
		info "Would append overrides from: $user_overrides"
		if [[ -f "$extensions_conf" ]]; then
			info "Would install extensions:"
			_dot_firefox_install_extensions "$profile_dir" true "$extensions_conf"
		fi
		return 0
	fi

	if [[ "$assume_yes" != "true" ]]; then
		warn "This will overwrite Firefox user.js for profile: $(basename "$profile_dir")"
		read -r -p "Continue? (y/N): " choice
		if [[ ! "$choice" =~ ^[Yy]$ ]]; then
			info "Firefox sync canceled"
			return 0
		fi
	fi

	step "Updating Firefox configuration"
	info "Using profile: $(basename "$profile_dir")"

	local arkenfox_url="https://raw.githubusercontent.com/arkenfox/user.js/master/user.js"
	if ! curl -fsSL "$arkenfox_url" -o "$profile_dir/user.js"; then
		error "Failed to download arkenfox user.js"
		return 1
	fi

	cat "$user_overrides" >>"$profile_dir/user.js"
	info "Firefox user.js updated successfully"

	if [[ -f "$extensions_conf" ]]; then
		step "Installing Firefox extensions"
		_dot_firefox_install_extensions "$profile_dir" false "$extensions_conf"
	fi

	info "Restart Firefox for changes to take effect"
}
