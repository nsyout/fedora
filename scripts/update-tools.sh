#!/bin/bash
# Update manually-managed tools (not in dnf repos)
# Usage: update-tools.sh [tool...]
# With no args, updates all tools.

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

info() { echo ":: $*"; }
error() { echo "!! $*" >&2; }

update_starship() {
	info "Updating starship..."
	local version
	version=$(curl -s https://api.github.com/repos/starship/starship/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
	local current
	current=$("$INSTALL_DIR/starship" --version 2>/dev/null | head -1 | awk '{print $2}') || current="none"

	info "  Current: $current"
	info "  Latest:  ${version#v}"

	if [[ "$current" == "${version#v}" ]]; then
		info "  Already up to date."
		return 0
	fi

	local url="https://github.com/starship/starship/releases/download/${version}/starship-x86_64-unknown-linux-gnu.tar.gz"
	local sha_url="${url}.sha256"

	curl -sL "$url" -o "$BUILD_DIR/starship.tar.gz"
	local expected
	expected=$(curl -sL "$sha_url")
	local actual
	actual=$(sha256sum "$BUILD_DIR/starship.tar.gz" | awk '{print $1}')

	if [[ "$expected" != "$actual" ]]; then
		error "  Checksum mismatch! Expected: $expected Got: $actual"
		return 1
	fi
	info "  Checksum verified."

	tar -xf "$BUILD_DIR/starship.tar.gz" -C "$BUILD_DIR"
	mv "$BUILD_DIR/starship" "$INSTALL_DIR/starship"
	chmod +x "$INSTALL_DIR/starship"
	info "  Installed starship ${version#v}"
}

update_ghostty() {
	info "Updating ghostty (tip)..."
	local current
	current=$("$INSTALL_DIR/ghostty" --version 2>/dev/null | head -1 | awk '{print $2}') || current="none"
	info "  Current: $current"

	local url="https://github.com/ghostty-org/ghostty/releases/download/tip/ghostty-source.tar.gz"
	local state_dir="$HOME/.local/state/dot"
	local hash_file="$state_dir/ghostty-tip.sha256"
	mkdir -p "$state_dir"

	# Download and check if anything changed since last build
	curl -sL "$url" -o "$BUILD_DIR/ghostty-source.tar.gz"
	local new_hash
	new_hash=$(sha256sum "$BUILD_DIR/ghostty-source.tar.gz" | awk '{print $1}')

	if [[ -f "$hash_file" ]]; then
		local old_hash
		old_hash=$(<"$hash_file")
		if [[ "$new_hash" == "$old_hash" ]]; then
			info "  Already up to date (tip tarball unchanged)."
			return 0
		fi
	fi

	tar -xf "$BUILD_DIR/ghostty-source.tar.gz" -C "$BUILD_DIR"

	local src_dir
	src_dir=$(find "$BUILD_DIR" -maxdepth 1 -name 'ghostty-*' -type d | head -1)

	if [[ -z "$src_dir" ]]; then
		error "  Could not find extracted source directory"
		return 1
	fi

	info "  New tip detected, building (this takes a few minutes)..."
	(cd "$src_dir" && zig build -Doptimize=ReleaseFast -p "$HOME/.local") 2>&1 | tail -5

	# Cache the hash so we skip next time if unchanged
	printf "%s\n" "$new_hash" >"$hash_file"

	local new_version
	new_version=$("$INSTALL_DIR/ghostty" --version 2>/dev/null | head -1 | awk '{print $2}') || new_version="unknown"
	info "  Installed ghostty $new_version"
}

update_lazygit() {
	info "Updating lazygit..."
	local version
	version=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
	local current
	current=$("$INSTALL_DIR/lazygit" --version 2>/dev/null | grep -oP '\bversion=\K[0-9][^,]+' | head -1) || current="none"

	info "  Current: $current"
	info "  Latest:  ${version#v}"

	if [[ "$current" == "${version#v}" ]]; then
		info "  Already up to date."
		return 0
	fi

	local url="https://github.com/jesseduffield/lazygit/releases/download/${version}/lazygit_${version#v}_Linux_x86_64.tar.gz"
	curl -sL "$url" -o "$BUILD_DIR/lazygit.tar.gz"
	tar -xf "$BUILD_DIR/lazygit.tar.gz" -C "$BUILD_DIR" lazygit
	install "$BUILD_DIR/lazygit" "$INSTALL_DIR/lazygit"
	info "  Installed lazygit ${version#v}"
}

update_nerdfonts() {
	info "Updating Nerd Fonts (Iosevka + IosevkaTerm)..."
	local font_dir="$HOME/.local/share/fonts/NerdFonts"
	local state_dir="$HOME/.local/state/dot"
	local version_file="$state_dir/nerdfonts.version"
	mkdir -p "$font_dir" "$state_dir"

	local version
	version=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep '"tag_name"' | cut -d'"' -f4)

	local current="none"
	[[ -f "$version_file" ]] && current=$(<"$version_file")

	info "  Current: $current"
	info "  Latest:  $version"

	if [[ "$current" == "$version" ]]; then
		info "  Already up to date."
		return 0
	fi

	local fonts=("Iosevka" "IosevkaTerm")
	for font in "${fonts[@]}"; do
		local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/${font}.tar.xz"
		info "  Downloading $font..."
		curl -sL "$url" -o "$BUILD_DIR/${font}.tar.xz"
		info "  Installing $font..."
		tar -xf "$BUILD_DIR/${font}.tar.xz" -C "$font_dir"
	done

	fc-cache -f
	printf "%s\n" "$version" >"$version_file"
	info "  Installed Iosevka + IosevkaTerm Nerd Fonts $version"
}

update_bluetuith() {
	info "Updating bluetuith..."
	local version
	version=$(curl -sL https://api.github.com/repos/bluetuith-org/bluetuith/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
	local current
	current=$("$INSTALL_DIR/bluetuith" --version 2>/dev/null | awk '{print $NF}') || current="none"

	info "  Current: $current"
	info "  Latest:  $version"

	if [[ "$current" == "$version" ]]; then
		info "  Already up to date."
		return 0
	fi

	local url="https://github.com/bluetuith-org/bluetuith/releases/download/${version}/bluetuith_${version#v}_Linux_x86_64.tar.gz"
	curl -sL "$url" -o "$BUILD_DIR/bluetuith.tar.gz"
	tar -xf "$BUILD_DIR/bluetuith.tar.gz" -C "$BUILD_DIR" bluetuith
	install "$BUILD_DIR/bluetuith" "$INSTALL_DIR/bluetuith"
	info "  Installed bluetuith $version"
}

# Main
tools=("$@")
if [[ ${#tools[@]} -eq 0 ]]; then
	tools=(starship ghostty lazygit nerdfonts bluetuith)
fi

for tool in "${tools[@]}"; do
	case "$tool" in
	starship) update_starship ;;
	ghostty) update_ghostty ;;
	lazygit) update_lazygit ;;
	nerdfonts) update_nerdfonts ;;
	bluetuith) update_bluetuith ;;
	*) error "Unknown tool: $tool" ;;
	esac
	echo
done
