#!/usr/bin/env bash

# Manage external zsh plugins declared in <platform>/zsh/plugins/external.txt

dot_plugins_sync() {
	local plugins_dir="$DOT_PLATFORM_DIR/zsh/plugins"
	local manifest="$plugins_dir/external.txt"

	if [[ ! -f "$manifest" ]]; then
		info "No external plugins manifest found"
		return 0
	fi

	step "Syncing external zsh plugins"

	local name url
	while IFS=' ' read -r name url; do
		# Skip comments and blank lines
		[[ -z "$name" || "$name" == \#* ]] && continue

		local plugin_dir="$plugins_dir/$name"

		if [[ -d "$plugin_dir/.git" ]]; then
			info "  Updating: $name"
			git -C "$plugin_dir" pull --quiet 2>/dev/null || warn "  Failed to update $name"
		elif [[ -d "$plugin_dir" ]]; then
			warn "  $name exists but is not a git repo, skipping"
		else
			info "  Cloning: $name"
			git clone --depth 1 --quiet "$url" "$plugin_dir" 2>/dev/null || warn "  Failed to clone $name"
		fi
	done <"$manifest"

	info "Plugin sync complete."
}

dot_plugins_list() {
	local manifest="$DOT_PLATFORM_DIR/zsh/plugins/external.txt"

	if [[ ! -f "$manifest" ]]; then
		info "No external plugins manifest"
		return 0
	fi

	local name url
	while IFS=' ' read -r name url; do
		[[ -z "$name" || "$name" == \#* ]] && continue
		local plugin_dir="$DOT_PLATFORM_DIR/zsh/plugins/$name"
		if [[ -d "$plugin_dir" ]]; then
			info "  $name (installed)"
		else
			warn "  $name (not installed)"
		fi
	done <"$manifest"
}
