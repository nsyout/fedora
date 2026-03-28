#!/usr/bin/env bash

dot_stow_manifest_files() {
	local profile="$1"
	local dotfiles_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"

	local base_manifest="$dotfiles_dir/stow-manifest.base"
	[[ -f "$base_manifest" ]] && printf "%s\n" "$base_manifest"

	case "$profile" in
	personal)
		[[ -f "$dotfiles_dir/stow-manifest.personal" ]] && printf "%s\n" "$dotfiles_dir/stow-manifest.personal"
		;;
	base) ;;
	*)
		warn "Unknown profile '$profile', using base stow manifest only"
		;;
	esac
}

dot_stow_profile_packages() {
	local profile="$1"
	local manifest
	while IFS= read -r manifest; do
		[[ -z "$manifest" ]] && continue
		while IFS= read -r line; do
			line="${line%%#*}"
			line="${line%%$'\r'}"
			[[ -z "$line" ]] && continue
			printf "%s\n" "$line"
		done <"$manifest"
	done < <(dot_stow_manifest_files "$profile")
}

dot_stow_apply() {
	local profile="$1"
	local assume_yes="${2:-false}"
	local dotfiles_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"

	step "Deploying dotfiles (profile: $profile)"

	# Root-level links
	info "Deploying root-level links..."

	# .zshenv
	if [[ -f "$dotfiles_dir/.zshenv" ]]; then
		ln -sf "$dotfiles_dir/.zshenv" "$HOME/.zshenv"
		info "  OK: .zshenv"
	fi

	# dot -> ~/.local/bin/dot
	local dot_target="$HOME/.local/bin/dot"
	mkdir -p "$(dirname "$dot_target")"
	if [[ -L "$dot_target" ]]; then
		info "  OK: ~/.local/bin/dot"
	else
		ln -s "$dotfiles_dir/dot" "$dot_target"
		info "  LINKED: ~/.local/bin/dot"
	fi

	# Config directories from stow manifests
	mkdir -p "$HOME/.config"

	local package
	while IFS= read -r package; do
		[[ -z "$package" ]] && continue
		local source_path="$dotfiles_dir/$package"
		local target_path="$HOME/.config/$package"

		if [[ ! -d "$source_path" ]]; then
			warn "  Package dir missing: $package"
			continue
		fi

		if [[ -L "$target_path" ]]; then
			info "  OK: $package"
		elif [[ -e "$target_path" ]]; then
			if [[ "$assume_yes" == "true" ]]; then
				rm -rf "$target_path"
				ln -s "$source_path" "$target_path"
				info "  REPLACED: $package"
			else
				warn "  SKIP: $package (exists, not a symlink)"
			fi
		else
			ln -s "$source_path" "$target_path"
			info "  LINKED: $package"
		fi
	done < <(dot_stow_profile_packages "$profile")

	# Systemd user units
	mkdir -p "$HOME/.config/systemd/user"
	for unit in "$dotfiles_dir"/systemd/user/*; do
		[[ -f "$unit" ]] || continue
		local unit_name
		unit_name="$(basename "$unit")"
		local unit_target="$HOME/.config/systemd/user/$unit_name"
		if [[ -L "$unit_target" ]]; then
			info "  OK: systemd/$unit_name"
		elif [[ ! -e "$unit_target" ]]; then
			ln -s "$unit" "$unit_target"
			info "  LINKED: systemd/$unit_name"
		fi
	done

	info "Done."
}
