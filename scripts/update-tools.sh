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
    curl -sL "$url" -o "$BUILD_DIR/ghostty-source.tar.gz"
    tar -xf "$BUILD_DIR/ghostty-source.tar.gz" -C "$BUILD_DIR"

    local src_dir
    src_dir=$(find "$BUILD_DIR" -maxdepth 1 -name 'ghostty-*' -type d | head -1)

    if [[ -z "$src_dir" ]]; then
        error "  Could not find extracted source directory"
        return 1
    fi

    info "  Building (this takes a few minutes)..."
    (cd "$src_dir" && zig build -Doptimize=ReleaseFast -p "$HOME/.local") 2>&1 | tail -5

    local new_version
    new_version=$("$INSTALL_DIR/ghostty" --version 2>/dev/null | head -1 | awk '{print $2}') || new_version="unknown"
    info "  Installed ghostty $new_version"
}

# Main
tools=("$@")
if [[ ${#tools[@]} -eq 0 ]]; then
    tools=(starship ghostty)
fi

for tool in "${tools[@]}"; do
    case "$tool" in
        starship) update_starship ;;
        ghostty)  update_ghostty ;;
        *) error "Unknown tool: $tool" ;;
    esac
    echo
done
