#!/usr/bin/env bash

# Path to the single symlink manifest for the current platform.
dot_symlink_manifest_file() {
	printf "%s\n" "$DOT_PLATFORM_DIR/symlink-manifest"
}

# Read config directory names from the symlink manifest.
dot_symlink_packages() {
	local manifest
	manifest="$(dot_symlink_manifest_file)"
	[[ -f "$manifest" ]] || return 0
	while IFS= read -r line; do
		line="${line%%#*}"
		line="${line%%$'\r'}"
		[[ -z "$line" ]] && continue
		printf "%s\n" "$line"
	done <"$manifest"
}

_dot_symlink_path_is_managed_tree() {
	local source_path="$1"
	local target_path="$2"

	[[ -d "$target_path" && ! -L "$target_path" ]] || return 1

	local bad_entry
	bad_entry="$(find "$target_path" -mindepth 1 \( -type f -o -type b -o -type c -o -type p -o -type s \) -print -quit)"
	[[ -z "$bad_entry" ]] || return 1

	local saw_symlink="false"
	local entry current_target
	while IFS= read -r entry; do
		saw_symlink="true"
		current_target="$(readlink "$entry")"
		[[ "$current_target" == "$source_path"/* ]] || return 1
	done < <(find "$target_path" -type l)

	[[ "$saw_symlink" == "true" ]]
}

_dot_symlink_link_path() {
	local source_path="$1"
	local target_path="$2"
	local assume_yes="${3:-false}"
	local label="$4"

	mkdir -p "$(dirname "$target_path")"

	if [[ -L "$target_path" ]]; then
		local current_target
		current_target="$(readlink "$target_path")"
		if [[ "$current_target" == "$source_path" ]]; then
			info "  OK: $label"
		else
			rm "$target_path"
			ln -s "$source_path" "$target_path"
			info "  UPDATED: $label"
		fi
	elif [[ -d "$source_path" ]] && _dot_symlink_path_is_managed_tree "$source_path" "$target_path"; then
		rm -rf "$target_path"
		ln -s "$source_path" "$target_path"
		info "  CONSOLIDATED: $label"
	elif [[ -e "$target_path" ]]; then
		if [[ "$assume_yes" == "true" ]]; then
			rm -rf "$target_path"
			ln -s "$source_path" "$target_path"
			info "  REPLACED: $label"
		else
			warn "  SKIP: $label (exists, not a symlink)"
		fi
	else
		ln -s "$source_path" "$target_path"
		info "  LINKED: $label"
	fi
}

# Deploy the home/ tree by walking its files and symlinking each one
# into the corresponding location under ~/. Creates parent dirs as needed.
# Runtime/package-manager artifact directories are pruned so dot symlink only
# deploys source-controlled config files.
_dot_symlink_deploy_home() {
	local home_src="$1"
	local assume_yes="${2:-false}"

	local -a find_args=(
		"$home_src"
		\( -name node_modules -o -name .pnpm -o -name .pnpm-store -o -name .cache -o -name dist -o -name build -o -name .turbo \) -prune
		-o -type f -print
	)

	local file rel_path target_path
	while IFS= read -r file; do
		rel_path="${file#"$home_src/"}"
		target_path="$HOME/$rel_path"
		_dot_symlink_link_path "$file" "$target_path" "$assume_yes" "~/$rel_path"
	done < <(find "${find_args[@]}")
}

# Deploy dotfiles by symlinking platform config dirs into ~/.config.
dot_symlink_apply() {
	local assume_yes="${1:-false}"
	local platform_dir="$DOT_PLATFORM_DIR"

	step "Deploying dotfiles (platform: $DOT_PLATFORM)"

	# Root-level links
	info "Deploying root-level links..."

	# dot -> ~/.local/bin/dot
	local dot_target="$HOME/.local/bin/dot"
	mkdir -p "$(dirname "$dot_target")"
	if [[ -L "$dot_target" ]]; then
		local dot_current
		dot_current="$(readlink "$dot_target")"
		if [[ "$dot_current" == "$DOTFILES_DIR/dot" ]]; then
			info "  OK: ~/.local/bin/dot"
		else
			rm "$dot_target"
			ln -s "$DOTFILES_DIR/dot" "$dot_target"
			info "  UPDATED: ~/.local/bin/dot (was: $dot_current)"
		fi
	else
		ln -s "$DOTFILES_DIR/dot" "$dot_target"
		info "  LINKED: ~/.local/bin/dot"
	fi

	# Deploy home/ tree: files mirror directly into ~/
	# Contains .zshenv, .claude/, and other root-level dotfiles
	if [[ -d "$platform_dir/home" ]]; then
		info "Deploying home tree..."
		_dot_symlink_deploy_home "$platform_dir/home" "$assume_yes"
	fi

	# Config directories from the symlink manifest
	mkdir -p "$HOME/.config"

	local config_dir
	while IFS= read -r config_dir; do
		[[ -z "$config_dir" ]] && continue
		local source_path="$platform_dir/$config_dir"
		local target_path="$HOME/.config/$config_dir"

		if [[ ! -d "$source_path" ]]; then
			warn "  Config dir missing: $config_dir (expected $source_path)"
			continue
		fi

		if [[ -L "$target_path" ]]; then
			local current_target
			current_target="$(readlink "$target_path")"
			if [[ "$current_target" == "$source_path" ]]; then
				info "  OK: $config_dir"
			else
				rm "$target_path"
				ln -s "$source_path" "$target_path"
				info "  UPDATED: $config_dir (was: $current_target)"
			fi
		elif [[ -e "$target_path" ]]; then
			if [[ "$assume_yes" == "true" ]]; then
				rm -rf "$target_path"
				ln -s "$source_path" "$target_path"
				info "  REPLACED: $config_dir"
			else
				warn "  SKIP: $config_dir (exists, not a symlink)"
			fi
		else
			ln -s "$source_path" "$target_path"
			info "  LINKED: $config_dir"
		fi
	done < <(dot_symlink_packages)

	# Systemd user units
	if [[ -d "$platform_dir/systemd/user" ]]; then
		mkdir -p "$HOME/.config/systemd/user"
		for unit in "$platform_dir"/systemd/user/*; do
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
	fi

	info "Done."
}
