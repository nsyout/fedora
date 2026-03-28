#!/usr/bin/env bash

# Tools managed outside of dnf (by update-tools.sh)
DOT_EXTERNAL_TOOLS="starship lazygit ghostty bluetuith"

dot_packages_manifest_files() {
	local profile="$1"
	local dotfiles_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"

	local base_manifest="$dotfiles_dir/packages.base"
	[[ -f "$base_manifest" ]] && printf "%s\n" "$base_manifest"

	case "$profile" in
	personal)
		[[ -f "$dotfiles_dir/packages.personal" ]] && printf "%s\n" "$dotfiles_dir/packages.personal"
		;;
	base) ;;
	*)
		warn "Unknown profile '$profile', using base packages only"
		;;
	esac
}

dot_packages_read_manifest() {
	local manifest="$1"
	while IFS= read -r line; do
		line="${line%%#*}"             # strip comments
		line="${line%%$'\r'}"          # strip CR
		line="$(echo "$line" | xargs)" # trim whitespace
		[[ -z "$line" ]] && continue
		printf "%s\n" "$line"
	done <"$manifest"
}

dot_packages_list() {
	local profile="$1"
	local manifest
	while IFS= read -r manifest; do
		[[ -z "$manifest" ]] && continue
		dot_packages_read_manifest "$manifest"
	done < <(dot_packages_manifest_files "$profile")
}

dot_packages_dnf_list() {
	local profile="$1"
	local pkg
	while IFS= read -r pkg; do
		# Skip externally managed tools
		local is_external=false
		for ext in $DOT_EXTERNAL_TOOLS; do
			if [[ "$pkg" == "$ext" ]]; then
				is_external=true
				break
			fi
		done
		[[ "$is_external" == "true" ]] && continue
		printf "%s\n" "$pkg"
	done < <(dot_packages_list "$profile")
}

dot_flatpak_manifest_files() {
	local profile="$1"
	local dotfiles_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"

	# No base flatpak manifest — flatpaks are profile-specific
	case "$profile" in
	personal)
		[[ -f "$dotfiles_dir/flatpaks.personal" ]] && printf "%s\n" "$dotfiles_dir/flatpaks.personal"
		;;
	esac
}

dot_flatpak_list() {
	local profile="$1"
	local manifest
	while IFS= read -r manifest; do
		[[ -z "$manifest" ]] && continue
		dot_packages_read_manifest "$manifest"
	done < <(dot_flatpak_manifest_files "$profile")
}

dot_flatpak_sync() {
	local profile="$1"

	if ! command_exists flatpak; then
		warn "Flatpak not installed, skipping flatpak sync"
		return 0
	fi

	local apps
	apps="$(dot_flatpak_list "$profile")"
	[[ -z "$apps" ]] && return 0

	info "Syncing Flatpak apps..."
	local app
	while IFS= read -r app; do
		[[ -z "$app" ]] && continue
		if flatpak info "$app" >/dev/null 2>&1; then
			info "  OK: $app"
		else
			info "  INSTALLING: $app"
			flatpak install -y --noninteractive flathub "$app"
		fi
	done <<<"$apps"
}

dot_flatpak_update() {
	if ! command_exists flatpak; then
		return 0
	fi

	info "Updating Flatpak apps..."
	flatpak update -y --noninteractive
}

dot_flatpak_check() {
	local profile="$1"
	# Sets _flatpak_missing as a side effect (can't return via stdout due to info/warn)
	_flatpak_missing=0

	if ! command_exists flatpak; then
		warn "Flatpak not installed"
		return 0
	fi

	local apps
	apps="$(dot_flatpak_list "$profile")"
	[[ -z "$apps" ]] && return 0

	local app
	while IFS= read -r app; do
		[[ -z "$app" ]] && continue
		if flatpak info "$app" >/dev/null 2>&1; then
			info "  OK: $app (flatpak)"
		else
			warn "  MISSING: $app (flatpak)"
			_flatpak_missing=$((_flatpak_missing + 1))
		fi
	done <<<"$apps"
}

dot_packages_sync() {
	local profile="$1"

	step "Syncing packages (profile: $profile)"

	local packages
	packages="$(dot_packages_dnf_list "$profile")"

	if [[ -n "$packages" ]]; then
		info "Installing/verifying DNF packages..."
		# shellcheck disable=SC2086
		sudo dnf install -y --skip-unavailable $packages
	fi

	info "Updating externally managed tools..."
	"$DOTFILES_DIR/scripts/update-tools.sh"

	dot_flatpak_sync "$profile"

	info "Package sync complete."
}

dot_packages_check() {
	local profile="$1"

	step "Checking packages (profile: $profile)"

	local missing=0
	local pkg
	while IFS= read -r pkg; do
		# Check externally managed tools by command name
		local is_external=false
		for ext in $DOT_EXTERNAL_TOOLS; do
			if [[ "$pkg" == "$ext" ]]; then
				is_external=true
				if command_exists "$pkg"; then
					info "  OK: $pkg (external)"
				else
					warn "  MISSING: $pkg (install via: update-tools.sh $pkg)"
					missing=$((missing + 1))
				fi
				break
			fi
		done
		[[ "$is_external" == "true" ]] && continue

		# Check dnf packages
		if rpm -q "$pkg" >/dev/null 2>&1; then
			info "  OK: $pkg"
		else
			warn "  MISSING: $pkg"
			missing=$((missing + 1))
		fi
	done < <(dot_packages_list "$profile")

	# Check flatpaks
	dot_flatpak_check "$profile"
	missing=$((missing + _flatpak_missing))

	if [[ "$missing" -gt 0 ]]; then
		warn "$missing package(s) missing. Run: dot packages sync"
	else
		info "All packages installed."
	fi
}

dot_cmd_packages() {
	local action="${1:-help}"
	shift || true

	local requested_profile=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--profile)
			shift
			requested_profile="${1:-}"
			;;
		-h | --help)
			cat <<'EOF'
Usage: dot packages <sync|check|list> [--profile <base|personal>]

Commands:
  sync    Install all packages for profile
  check   Check which packages are missing
  list    List all packages for profile
EOF
			return 0
			;;
		*)
			error "Unknown option for dot packages: $1"
			return 1
			;;
		esac
		shift
	done

	local profile
	if [[ -n "$requested_profile" ]]; then
		if ! dot_profile_is_valid "$requested_profile"; then
			error "Invalid profile '$requested_profile'. Use: base, personal"
			return 1
		fi
		profile="$requested_profile"
	else
		profile="$(dot_profile_get)"
	fi

	case "$action" in
	sync)
		dot_packages_sync "$profile"
		;;
	check)
		dot_packages_check "$profile"
		;;
	list)
		dot_packages_list "$profile"
		;;
	-h | --help | help)
		cat <<'EOF'
Usage: dot packages <sync|check|list> [--profile <base|personal>]

Commands:
  sync    Install all packages for profile
  check   Check which packages are missing
  list    List all packages for profile
EOF
		;;
	*)
		error "Unknown packages action: $action"
		return 1
		;;
	esac
}
