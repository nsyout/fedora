#!/usr/bin/env bash

# linux-dotfiles is Linux-only.
# Sets DOT_PLATFORM and DOT_PLATFORM_DIR for compatibility with shared libs.

dot_platform_detect() {
	if [[ "$(uname -s)" != "Linux" ]]; then
		error "linux-dotfiles is Linux-only (detected: $(uname -s))"
		return 1
	fi

	DOT_PLATFORM="linux"
	DOT_PLATFORM_DIR="$DOTFILES_DIR/linux"
}

dot_platform_require() {
	local required_platform="$1"
	local current_platform="${DOT_PLATFORM:-unknown}"

	if [[ "$current_platform" != "$required_platform" ]]; then
		error "This command requires $required_platform (detected: $current_platform)"
		return 1
	fi
}
