#!/usr/bin/env bash

# Linux package management via dnf + Flatpak.

# --------------------------------------------------------------------------
# Shared helpers
# --------------------------------------------------------------------------

dot_packages_read_manifest_lines() {
	local manifest="$1"
	while IFS= read -r line; do
		line="${line%%#*}"
		line="${line%%$'\r'}"
		line="$(echo "$line" | xargs)"
		[[ -z "$line" ]] && continue
		printf "%s\n" "$line"
	done <"$manifest"
}

# --------------------------------------------------------------------------
# Manifest file resolution
# --------------------------------------------------------------------------

dot_packages_manifest_file() {
	printf "%s\n" "$DOT_PLATFORM_DIR/packages"
}

# --------------------------------------------------------------------------
# Package list (for display / check)
# --------------------------------------------------------------------------

dot_packages_list() {
	local manifest
	manifest="$(dot_packages_manifest_file)"
	[[ -f "$manifest" ]] || {
		warn "Missing manifest: $manifest"
		return 1
	}

	dot_packages_read_manifest_lines "$manifest"
}

# --------------------------------------------------------------------------
# Package sync
# --------------------------------------------------------------------------

dot_packages_sync() {
	local platform_dir="$DOT_PLATFORM_DIR"
	local manifest
	manifest="$(dot_packages_manifest_file)"

	# Tools managed outside of dnf
	local external_tools="starship lazygit ghostty gallery-dl bluetuith wiremix opensnitch yazi"

	step "Syncing packages"

	if [[ ! -f "$manifest" ]]; then
		warn "Missing manifest: $manifest"
		return 1
	fi

	local packages=""
	local pkg
	while IFS= read -r pkg; do
		# Skip externally managed tools
		local is_external=false
		for ext in $external_tools; do
			if [[ "$pkg" == "$ext" ]]; then
				is_external=true
				break
			fi
		done
		[[ "$is_external" == "true" ]] && continue
		packages="$packages $pkg"
	done < <(dot_packages_read_manifest_lines "$manifest")

	if [[ -n "$packages" ]]; then
		info "Installing/verifying DNF packages..."
		# shellcheck disable=SC2086
		sudo dnf install -y --skip-unavailable $packages
	fi

	if [[ -x "$platform_dir/../scripts/update-tools.sh" ]]; then
		info "Updating externally managed tools..."
		"$platform_dir/../scripts/update-tools.sh"
	fi

	# Flatpaks
	_dot_flatpak_sync

	info "Package sync complete."
}

# --------------------------------------------------------------------------
# Package check
# --------------------------------------------------------------------------

dot_packages_check() {
	local external_tools="starship lazygit ghostty gallery-dl bluetuith wiremix opensnitch yazi"
	local manifest
	manifest="$(dot_packages_manifest_file)"

	step "Checking packages"

	if [[ ! -f "$manifest" ]]; then
		warn "Missing manifest: $manifest"
		return 1
	fi

	local missing=0
	local pkg
	while IFS= read -r pkg; do
		local is_external=false
		for ext in $external_tools; do
			if [[ "$pkg" == "$ext" ]]; then
				is_external=true
				if command_exists "$pkg"; then
					info "  OK: $pkg (external)"
				else
					warn "  MISSING: $pkg (install via: scripts/update-tools.sh $pkg)"
					missing=$((missing + 1))
				fi
				break
			fi
		done
		[[ "$is_external" == "true" ]] && continue

		if rpm -q "$pkg" >/dev/null 2>&1; then
			info "  OK: $pkg"
		else
			warn "  MISSING: $pkg"
			missing=$((missing + 1))
		fi
	done < <(dot_packages_read_manifest_lines "$manifest")

	_dot_flatpak_check
	missing=$((missing + _flatpak_missing))

	if [[ "$missing" -gt 0 ]]; then
		warn "$missing package(s) missing. Run: dot packages sync"
	else
		info "All packages installed."
	fi
}

# --------------------------------------------------------------------------
# Flatpak helpers
# --------------------------------------------------------------------------

_dot_flatpak_manifest_file() {
	printf "%s\n" "$DOT_PLATFORM_DIR/flatpaks"
}

_dot_flatpak_sync() {
	if ! command_exists flatpak; then
		return 0
	fi

	local apps
	apps="$(_dot_flatpak_list)"
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

_dot_flatpak_list() {
	local manifest
	manifest="$(_dot_flatpak_manifest_file)"
	[[ -f "$manifest" ]] || return 0
	dot_packages_read_manifest_lines "$manifest"
}

_dot_flatpak_check() {
	_flatpak_missing=0

	if ! command_exists flatpak; then
		return 0
	fi

	local apps
	apps="$(_dot_flatpak_list)"
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

# --------------------------------------------------------------------------
# Dispatch: dot packages <action>
# --------------------------------------------------------------------------

dot_cmd_packages() {
	local action="${1:-help}"
	shift || true

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			cat <<'EOF'
Usage: dot packages <sync|check|list>

Commands:
  sync    Install all packages
  check   Check which packages are missing
  list    List all packages
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

	case "$action" in
	sync) dot_packages_sync ;;
	check) dot_packages_check ;;
	list) dot_packages_list ;;
	-h | --help | help)
		cat <<'EOF'
Usage: dot packages <sync|check|list>

Commands:
  sync    Install all packages
  check   Check which packages are missing
  list    List all packages
EOF
		;;
	*)
		error "Unknown packages action: $action"
		return 1
		;;
	esac
}
