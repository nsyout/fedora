#!/usr/bin/env bash

dot_cmd_update() {
	dot_platform_require "linux" || return 1

	info "Updating system packages..."
	sudo dnf update -y

	info ""
	dot_packages_sync

	info ""
	info "Updating Flatpak apps..."
	if command_exists flatpak; then
		flatpak update -y --noninteractive
	fi

	info ""
	info "Syncing zsh plugins..."
	dot_plugins_sync

	info ""
	info "Re-deploying system configs..."
	dot_cmd_system

	info ""
	info "Re-deploying symlinked config directories..."
	dot_symlink_apply

	info ""
	info "Done."
}
