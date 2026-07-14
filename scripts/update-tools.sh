#!/bin/bash
# Update manually-managed tools (not in dnf repos)
# Usage: update-tools.sh [tool...]
# With no args, updates all tools.

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

info() { echo ":: $*"; }
error() { echo "!! $*" >&2; }

github_latest_stable_tag() {
	local repository="$1"
	curl -fsSL -H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/${repository}/tags?per_page=100" |
		jq -er '
			[.[].name
			| capture("^v?(?<major>[0-9]+)\\.(?<minor>[0-9]+)\\.(?<patch>[0-9]+)$")
			| .major |= tonumber
			| .minor |= tonumber
			| .patch |= tonumber]
			| max_by([.major, .minor, .patch])
			| "v\(.major).\(.minor).\(.patch)"
		'
}

ghostty_required_zig_version() {
	local source_dir="$1"
	local manifest="$source_dir/build.zig.zon"

	[[ -f "$manifest" ]] || return 1
	sed -nE 's/.*\.minimum_zig_version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$manifest" | head -1
}

zig_download_target() {
	case "$(uname -m)" in
	x86_64) printf '%s\n' "x86_64-linux" ;;
	aarch64 | arm64) printf '%s\n' "aarch64-linux" ;;
	*) return 1 ;;
	esac
}

zig_for_version() {
	local required_version="$1"
	local system_zig=""
	local system_version="none"

	if system_zig=$(command -v zig 2>/dev/null); then
		system_version=$("$system_zig" version 2>/dev/null || true)
		if [[ "$system_version" == "$required_version" ]]; then
			printf '%s\n' "$system_zig"
			return 0
		fi
	fi

	local cache_root="$HOME/.local/share/dot/zig"
	local install_dir="$cache_root/$required_version"
	local cached_zig="$install_dir/zig"
	if [[ -x "$cached_zig" && "$($cached_zig version 2>/dev/null || true)" == "$required_version" ]]; then
		printf '%s\n' "$cached_zig"
		return 0
	fi

	if [[ -e "$install_dir" ]]; then
		error "  Cached Zig $required_version is incomplete: $install_dir"
		return 1
	fi

	local target
	if ! target=$(zig_download_target); then
		error "  Unsupported architecture for managed Zig: $(uname -m)"
		return 1
	fi

	info "  System Zig $system_version does not match required $required_version; installing managed Zig..." >&2
	local index_file="$BUILD_DIR/zig-download-index.json"
	curl -fsSL "https://ziglang.org/download/index.json" -o "$index_file"

	local archive_url
	local expected_sha
	if ! archive_url=$(jq -er --arg version "$required_version" --arg target "$target" \
		'.[$version][$target].tarball' "$index_file") ||
		! expected_sha=$(jq -er --arg version "$required_version" --arg target "$target" \
			'.[$version][$target].shasum' "$index_file"); then
		error "  Zig $required_version has no $target download in the official index"
		return 1
	fi

	local archive="$BUILD_DIR/zig-$required_version.tar"
	curl -fsSL "$archive_url" -o "$archive"
	if ! printf '%s  %s\n' "$expected_sha" "$archive" | sha256sum --check --status; then
		error "  Checksum verification failed for Zig $required_version"
		return 1
	fi

	local extract_dir="$BUILD_DIR/zig-$required_version"
	mkdir -p "$extract_dir"
	tar -xf "$archive" -C "$extract_dir" --strip-components=1
	if [[ ! -x "$extract_dir/zig" || "$("$extract_dir/zig" version 2>/dev/null || true)" != "$required_version" ]]; then
		error "  Downloaded Zig archive did not contain the expected compiler"
		return 1
	fi

	mkdir -p "$cache_root"
	mv "$extract_dir" "$install_dir"
	printf '%s\n' "$cached_zig"
}

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
	install "$BUILD_DIR/starship" "$INSTALL_DIR/starship"
	info "  Installed starship ${version#v}"
}

update_ghostty() {
	info "Updating ghostty (stable)..."
	local current
	current=$("$INSTALL_DIR/ghostty" --version 2>/dev/null | head -1 | awk '{print $2}') || current="none"
	info "  Current: $current"

	local latest_tag
	if ! latest_tag=$(github_latest_stable_tag "ghostty-org/ghostty"); then
		error "  Could not determine latest stable release"
		return 1
	fi
	local version="${latest_tag#v}"

	info "  Latest stable: $version"

	# Strip -dev+hash suffix from tip builds for comparison
	local current_base="${current%%-*}"
	if [[ "$current_base" == "$version" ]]; then
		info "  Already up to date."
		return 0
	fi

	local url="https://release.files.ghostty.org/${version}/ghostty-${version}.tar.gz"
	curl -fsSL "$url" -o "$BUILD_DIR/ghostty-source.tar.gz"

	tar -xf "$BUILD_DIR/ghostty-source.tar.gz" -C "$BUILD_DIR"

	local src_dir
	src_dir=$(find "$BUILD_DIR" -maxdepth 1 -name 'ghostty-*' -type d | head -1)

	if [[ -z "$src_dir" ]]; then
		error "  Could not find extracted source directory"
		return 1
	fi

	local required_zig
	if ! required_zig=$(ghostty_required_zig_version "$src_dir") || [[ -z "$required_zig" ]]; then
		error "  Could not determine required Zig version from build.zig.zon"
		return 1
	fi
	info "  Required Zig: $required_zig"

	local zig_bin
	if ! zig_bin=$(zig_for_version "$required_zig"); then
		return 1
	fi
	info "  Using Zig: $zig_bin"

	local build_dependencies=(gtk4-devel gtk4-layer-shell-devel libadwaita-devel gettext pkgconf-pkg-config)
	local missing_dependencies=()
	local dependency
	for dependency in "${build_dependencies[@]}"; do
		if ! rpm -q "$dependency" >/dev/null 2>&1; then
			missing_dependencies+=("$dependency")
		fi
	done
	if [[ ${#missing_dependencies[@]} -gt 0 ]]; then
		info "  Installing missing build dependencies: ${missing_dependencies[*]}"
		sudo dnf install -y "${missing_dependencies[@]}"
	else
		info "  Build dependencies already installed."
	fi

	info "  Building $version (this takes a few minutes)..."
	(cd "$src_dir" && "$zig_bin" build -Doptimize=ReleaseFast -Dversion-string="$version" -p "$HOME/.local")

	local new_version
	new_version=$("$INSTALL_DIR/ghostty" --version 2>/dev/null | head -1 | awk '{print $2}') || new_version="unknown"
	if [[ "${new_version%%-*}" != "$version" ]]; then
		error "  Ghostty installation verification failed (expected $version, got $new_version)"
		return 1
	fi
	info "  Installed ghostty $new_version"
}

update_gallery_dl() {
	info "Updating gallery-dl (stable)..."
	if ! command -v uv >/dev/null 2>&1; then
		error "  uv is required to manage gallery-dl"
		return 1
	fi

	local current="none"
	if command -v gallery-dl >/dev/null 2>&1; then
		current=$(gallery-dl --version 2>/dev/null || true)
		[[ -n "$current" ]] || current="unknown"
	fi

	local latest
	if ! latest=$(curl -fsSL "https://pypi.org/pypi/gallery-dl/json" | jq -er '.info.version'); then
		error "  Could not determine latest stable gallery-dl release"
		return 1
	fi

	info "  Current: $current"
	info "  Latest:  $latest"
	if [[ "$current" == "$latest" ]]; then
		info "  Already up to date."
		return 0
	fi

	uv tool install --upgrade "gallery-dl==$latest"
	hash -r

	local new_version
	new_version=$("$INSTALL_DIR/gallery-dl" --version 2>/dev/null || true)
	if [[ "$new_version" != "$latest" ]]; then
		error "  gallery-dl installation verification failed (expected $latest, got ${new_version:-missing})"
		return 1
	fi
	info "  Installed gallery-dl $new_version"
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

update_wiremix() {
	info "Updating wiremix..."
	local current
	current=$(wiremix --version 2>/dev/null | awk '{print $2}') || current="none"
	local latest
	latest=$(curl -s https://crates.io/api/v1/crates/wiremix | grep -oP '"newest_version":"\K[^"]+')

	info "  Current: $current"
	info "  Latest:  $latest"

	if [[ "$current" == "$latest" ]]; then
		info "  Already up to date."
		return 0
	fi

	if [[ ! -f "$HOME/.cargo/env" ]]; then
		info "  Installing Rust..."
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
	fi
	. "$HOME/.cargo/env"
	sudo dnf install -y pipewire-devel clang
	cargo install wiremix
	info "  Installed wiremix $latest"
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

update_opensnitch() {
	info "Updating opensnitch..."
	local version
	version=$(curl -s https://api.github.com/repos/evilsocket/opensnitch/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
	local current
	current=$(rpm -q opensnitch --queryformat '%{VERSION}' 2>/dev/null) || current="none"

	info "  Current: $current"
	info "  Latest:  ${version#v}"

	if [[ "$current" == "${version#v}" ]]; then
		info "  Already up to date."
		return 0
	fi

	local base_url="https://github.com/evilsocket/opensnitch/releases/download/${version}"
	curl -sL "${base_url}/opensnitch-${version#v}-1.x86_64.rpm" -o "$BUILD_DIR/opensnitch.rpm"
	curl -sL "${base_url}/opensnitch-ui-${version#v}-1.noarch.rpm" -o "$BUILD_DIR/opensnitch-ui.rpm"
	sudo dnf install -y "$BUILD_DIR/opensnitch.rpm" "$BUILD_DIR/opensnitch-ui.rpm"
	info "  Installed opensnitch ${version#v}"
}

update_yazi() {
	info "Updating yazi..."
	local version
	version=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
	local current
	current=$("$INSTALL_DIR/yazi" --version 2>/dev/null | awk '{print $2}') || current="none"

	info "  Current: $current"
	info "  Latest:  ${version#v}"

	if [[ "$current" == "${version#v}" ]]; then
		info "  Already up to date."
		return 0
	fi

	local url="https://github.com/sxyazi/yazi/releases/download/${version}/yazi-x86_64-unknown-linux-gnu.zip"
	curl -sL "$url" -o "$BUILD_DIR/yazi.zip"
	unzip -qo "$BUILD_DIR/yazi.zip" -d "$BUILD_DIR/yazi-extract"
	install "$BUILD_DIR/yazi-extract/yazi-x86_64-unknown-linux-gnu/yazi" "$INSTALL_DIR/yazi"
	install "$BUILD_DIR/yazi-extract/yazi-x86_64-unknown-linux-gnu/ya" "$INSTALL_DIR/ya"
	info "  Installed yazi ${version#v}"
}

update_obsidian() {
	info "Updating Obsidian..."
	local version
	version=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
	local appimage="$INSTALL_DIR/Obsidian.AppImage"
	local state_dir="$HOME/.local/state/dot"
	local version_file="$state_dir/obsidian.version"
	mkdir -p "$state_dir"

	local current="none"
	[[ -f "$version_file" ]] && current=$(<"$version_file")

	info "  Current: $current"
	info "  Latest:  ${version#v}"

	if [[ "$current" == "${version#v}" ]]; then
		info "  Already up to date."
		return 0
	fi

	local url="https://github.com/obsidianmd/obsidian-releases/releases/download/${version}/Obsidian-${version#v}.AppImage"
	curl -sL "$url" -o "$appimage"
	chmod +x "$appimage"

	# Extract icon from AppImage
	local icons_dir="$HOME/.local/share/icons"
	mkdir -p "$icons_dir"
	(cd "$BUILD_DIR" && "$appimage" --appimage-extract usr/share/icons/hicolor/256x256/apps/obsidian.png >/dev/null 2>&1)
	cp "$BUILD_DIR/squashfs-root/usr/share/icons/hicolor/256x256/apps/obsidian.png" "$icons_dir/obsidian.png" 2>/dev/null || true
	rm -rf "$BUILD_DIR/squashfs-root"

	# Desktop entry for rofi/launchers
	local apps_dir="$HOME/.local/share/applications"
	mkdir -p "$apps_dir"
	cat >"$apps_dir/obsidian.desktop" <<DESKTOP
[Desktop Entry]
Name=Obsidian
Exec=$appimage
Icon=$icons_dir/obsidian.png
Type=Application
Categories=Office;
Comment=Knowledge base and note-taking
StartupWMClass=obsidian
DESKTOP

	printf "%s\n" "${version#v}" >"$version_file"
	info "  Installed Obsidian ${version#v}"
}

update_discord() {
	info "Updating Discord..."
	local install_dir="$HOME/.local/share/Discord"
	local state_dir="$HOME/.local/state/dot"
	local version_file="$state_dir/discord.version"
	mkdir -p "$state_dir"

	# Get latest version from redirect URL
	local redirect
	redirect=$(curl -sI 'https://discord.com/api/download?platform=linux&format=tar.gz' | grep -i '^location:' | tr -d '\r')
	local version
	version=$(echo "$redirect" | grep -oP 'discord-\K[0-9.]+(?=\.tar\.gz)')

	local current="none"
	[[ -f "$version_file" ]] && current=$(<"$version_file")

	info "  Current: $current"
	info "  Latest:  $version"

	if [[ "$current" == "$version" ]]; then
		info "  Already up to date."
		return 0
	fi

	local url
	url=$(echo "$redirect" | awk '{print $2}')
	curl -sL "$url" -o "$BUILD_DIR/discord.tar.gz"
	rm -rf "$install_dir"
	tar -xf "$BUILD_DIR/discord.tar.gz" -C "$HOME/.local/share"

	# Symlink binary
	ln -sf "$install_dir/Discord" "$INSTALL_DIR/discord"

	# Desktop entry for rofi/launchers
	local apps_dir="$HOME/.local/share/applications"
	mkdir -p "$apps_dir"
	cat >"$apps_dir/discord.desktop" <<DESKTOP
[Desktop Entry]
Name=Discord
Exec=$install_dir/Discord
Icon=$install_dir/discord.png
Type=Application
Categories=Network;InstantMessaging;
Comment=All-in-one voice and text chat
StartupWMClass=discord
DESKTOP

	printf "%s\n" "$version" >"$version_file"
	info "  Installed Discord $version"
}

# Main
_run_tool_update() {
	local tool="$1"
	local fn="update_${tool//-/_}"
	local tmp
	local status
	tmp=$(mktemp)
	# Calling a function directly in an `if` test disables errexit throughout
	# that function. Run it in a fail-fast subshell, then classify its status.
	set +e
	(
		set -e
		"$fn"
	) >"$tmp" 2>&1
	status=$?
	set -e
	if [[ "$status" -eq 0 ]]; then
		if grep -q "Already up to date" "$tmp"; then
			_skipped_tools+=("$tool")
		else
			cat "$tmp"
			echo
			_updated_tools+=("$tool")
		fi
	else
		cat "$tmp"
		echo
		_failed_tools+=("$tool")
	fi
	rm -f "$tmp"
}

main() {
	tools=("$@")
	if [[ ${#tools[@]} -eq 0 ]]; then
		tools=(starship ghostty gallery-dl lazygit nerdfonts bluetuith wiremix opensnitch yazi obsidian discord)
	fi

	_updated_tools=()
	_skipped_tools=()
	_failed_tools=()

	local tool
	for tool in "${tools[@]}"; do
		case "$tool" in
		starship | ghostty | gallery-dl | lazygit | nerdfonts | bluetuith | wiremix | opensnitch | yazi | obsidian | discord)
			_run_tool_update "$tool"
			;;
		*)
			error "Unknown tool: $tool"
			_failed_tools+=("$tool")
			;;
		esac
	done

	echo
	if [[ ${#_updated_tools[@]} -gt 0 ]]; then
		info "Updated: ${_updated_tools[*]}"
	fi
	if [[ ${#_skipped_tools[@]} -gt 0 ]]; then
		info "Up to date: ${_skipped_tools[*]}"
	fi
	if [[ ${#_failed_tools[@]} -gt 0 ]]; then
		error "Failed: ${_failed_tools[*]}"
		return 1
	fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
