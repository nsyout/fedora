#!/usr/bin/env bash

dot_theme_list() {
	local path
	for path in "$DOTFILES_DIR"/themes/*; do
		[[ -d "$path" ]] || continue
		basename "$path"
	done | sort
}

dot_theme_current() {
	local theme_file="$DOTFILES_DIR/config/theme/current-theme"
	if [[ -f "$theme_file" ]]; then
		cat "$theme_file"
	else
		echo "flexoki-dark"
	fi
}

dot_theme_set() {
	local theme_name="${1:-}"

	if [[ -z "$theme_name" ]]; then
		error "Usage: dot theme set <theme-name>"
		return 1
	fi

	if [[ ! -f "$DOTFILES_DIR/themes/$theme_name/colors.toml" ]]; then
		error "Unknown theme: $theme_name"
		info "Available themes:"
		dot_theme_list | while read -r t; do info "  - $t"; done
		return 1
	fi

	printf "%s\n" "$theme_name" >"$DOTFILES_DIR/config/theme/current-theme"
	dot_theme_render
	info "Set current theme to $theme_name"
}

dot_theme_render() {
	step "Rendering theme"
	local theme_name
	theme_name="$(dot_theme_current)"
	info "Theme: $theme_name"

	python3 - "$DOTFILES_DIR" <<'PY'
from pathlib import Path
import tomllib
import sys

dotfiles = Path(sys.argv[1])
theme_name = (dotfiles / "config/theme/current-theme").read_text().strip()
colors = tomllib.loads((dotfiles / f"themes/{theme_name}/colors.toml").read_text())

background = colors["background"]
foreground = colors["foreground"]

if background.lower() == "#fffcf0":
    panel_background = "rgba(255, 252, 240, 0.94)"
    muted_background = "#f2e9e1"
    border = "#cecdc3"
    muted_foreground = "#878580"
    subdued_foreground = "#575653"
else:
    def hex_to_rgba(h, alpha):
        r, g, b = int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)
        return f"rgba({r}, {g}, {b}, {alpha})"
    panel_background = hex_to_rgba(background, 0.92)
    muted_background = colors.get("color0", background)
    border = colors.get("color8", colors.get("selection_background", foreground))
    muted_foreground = colors.get("color8", foreground)
    subdued_foreground = colors.get("color7", foreground)

context = {
    **colors,
    "theme_name": theme_name,
    "ghostty_theme_name": {
        "catppuccin": "Catppuccin Mocha",
        "everforest": "Everforest Dark Hard",
        "flexoki-dark": "Flexoki Dark",
        "flexoki-light": "Flexoki Light",
        "gruvbox": "Gruvbox Dark",
        "kanagawa": "Kanagawa Wave",
        "nord": "Nord",
        "rose-pine": "Rose Pine",
        "tokyo-night": "TokyoNight",
    }.get(theme_name, theme_name.replace("-", " ").title()),
    "panel_background": panel_background,
    "muted_background": muted_background,
    "border": border,
    "muted_foreground": muted_foreground,
    "subdued_foreground": subdued_foreground,
    "accent_2": colors.get("color12", colors["accent"]),
    "accent_3": colors.get("color11", colors["accent"]),
    "urgent": colors.get("color1", colors["accent"]),
}

targets = [
    ("btop.theme.tpl",       dotfiles / "btop/themes/current.theme"),
    ("ghostty.conf.tpl",     dotfiles / "ghostty/config"),
    ("mako.ini.tpl",         dotfiles / "mako/config"),
    ("rofi-theme.rasi.tpl",  dotfiles / "rofi/theme.rasi"),
    ("sway-theme.conf.tpl",  dotfiles / "sway/config.d/10-theme.conf"),
    ("tmux.conf.tpl",        dotfiles / "tmux/tmux.conf"),
    ("waybar.css.tpl",       dotfiles / "waybar/style.css"),
]

tpl_dir = dotfiles / "config/theme-templates"
for tpl_name, output_path in targets:
    tpl_path = tpl_dir / tpl_name
    if not tpl_path.exists():
        print(f"  SKIP: {tpl_name} (template missing)")
        continue
    content = tpl_path.read_text()
    for key, value in context.items():
        content = content.replace(f"{{{{ {key} }}}}", str(value))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(content)
    print(f"  OK: {output_path.relative_to(dotfiles)}")
PY

	# Reload live apps if running
	if command_exists swaymsg && swaymsg -t get_version >/dev/null 2>&1; then
		pkill waybar 2>/dev/null
		swaymsg reload >/dev/null 2>&1 && info "Sway reloaded"
		makoctl reload 2>/dev/null && info "Mako reloaded"
	fi

	if command_exists tmux && tmux list-sessions >/dev/null 2>&1; then
		tmux source-file ~/.config/tmux/tmux.conf 2>/dev/null && info "Tmux reloaded"
	fi

	info "Done. Restart ghostty for terminal theme changes."
}

dot_cmd_theme() {
	local action="${1:-current}"
	shift || true

	case "$action" in
	list)
		dot_theme_list
		;;
	current)
		dot_theme_current
		;;
	set)
		dot_theme_set "$@"
		;;
	render)
		dot_theme_render
		;;
	-h | --help | help)
		cat <<'EOF'
Usage: dot theme <command>

Commands:
  current           Show current theme
  list              List available themes
  set <theme-name>  Set theme and render configs
  render            Re-render current theme
EOF
		;;
	*)
		error "Unknown theme action: $action"
		return 1
		;;
	esac
}
