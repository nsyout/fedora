#!/usr/bin/env bash

dot_wallpaper_repo_url() {
	printf "%s\n" "${DOT_WALLPAPER_REPO:-https://github.com/nsyout/walls.git}"
}

dot_wallpaper_dir() {
	printf "%s\n" "${DOT_WALLPAPER_DIR:-$HOME/projects/personal/walls}"
}

dot_wallpaper_image_list() {
	local wallpaper_dir="$1"

	if [[ ! -d "$wallpaper_dir" ]]; then
		return 0
	fi

	find "$wallpaper_dir" -type f \
		\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.tif' -o -iname '*.tiff' \) |
		sort
}

dot_wallpaper_sync() {
	local dry_run=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			dry_run=true
			;;
		-h | --help)
			cat <<'EOF'
Usage: dot wallpaper sync [--dry-run]
EOF
			return 0
			;;
		*)
			error "Unknown option for dot wallpaper sync: $1"
			return 1
			;;
		esac
		shift
	done

	local wallpaper_repo
	local wallpaper_dir
	wallpaper_repo="$(dot_wallpaper_repo_url)"
	wallpaper_dir="$(dot_wallpaper_dir)"

	if [[ "$dry_run" == "true" ]]; then
		step "Dry run"
		if [[ -d "$wallpaper_dir/.git" ]]; then
			info "Would update wallpaper repo in: $wallpaper_dir"
		else
			info "Would clone wallpaper repo: $wallpaper_repo"
			info "Would clone into: $wallpaper_dir"
		fi
		return 0
	fi

	step "Syncing wallpaper repository"
	if [[ -d "$wallpaper_dir/.git" ]]; then
		info "Updating wallpaper repo in: $wallpaper_dir"
		git -C "$wallpaper_dir" pull --ff-only || {
			warn "Failed to update wallpaper repository"
			return 1
		}
		return 0
	fi

	if [[ -e "$wallpaper_dir" ]]; then
		error "Wallpaper directory exists but is not a git repo: $wallpaper_dir"
		return 1
	fi

	mkdir -p "$(dirname "$wallpaper_dir")"
	info "Cloning wallpaper repo into: $wallpaper_dir"
	git clone "$wallpaper_repo" "$wallpaper_dir" || {
		warn "Unable to clone wallpaper repository"
		return 1
	}

	return 0
}

dot_wallpaper_list() {
	local wallpaper_dir
	local wallpaper_list
	wallpaper_dir="$(dot_wallpaper_dir)"
	wallpaper_list="$(dot_wallpaper_image_list "$wallpaper_dir")"

	if [[ -z "$wallpaper_list" ]]; then
		warn "No wallpapers found in: $wallpaper_dir"
		info "Run: dot wallpaper sync"
		return 1
	fi

	printf "%s\n" "$wallpaper_list" | sed "s#^$wallpaper_dir/##"
}

dot_wallpaper_set() {
	local wallpaper_path=""
	local dry_run=false
	local pick_mode=false
	local random_mode=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			dry_run=true
			;;
		--pick)
			pick_mode=true
			;;
		--random)
			random_mode=true
			;;
		-h | --help)
			cat <<'EOF'
Usage: dot wallpaper set [path] [--pick|--random] [--dry-run]
EOF
			return 0
			;;
		--*)
			error "Unknown option for dot wallpaper set: $1"
			return 1
			;;
		*)
			if [[ -n "$wallpaper_path" ]]; then
				error "Only one wallpaper path is supported"
				return 1
			fi
			wallpaper_path="$1"
			;;
		esac
		shift
	done

	if [[ "$pick_mode" == "true" && "$random_mode" == "true" ]]; then
		error "Use either --pick or --random, not both"
		return 1
	fi

	if [[ -n "$wallpaper_path" && ("$pick_mode" == "true" || "$random_mode" == "true") ]]; then
		error "Provide a path or choose --pick/--random"
		return 1
	fi

	local wallpaper_dir
	local wallpaper_list
	wallpaper_dir="$(dot_wallpaper_dir)"

	if [[ -z "$wallpaper_path" ]]; then
		if [[ ! -d "$wallpaper_dir/.git" ]]; then
			warn "Wallpaper repository not found at $wallpaper_dir; syncing now"
			dot_wallpaper_sync || return 1
		fi

		wallpaper_list="$(dot_wallpaper_image_list "$wallpaper_dir")"
		if [[ -z "$wallpaper_list" ]]; then
			error "No wallpapers found in: $wallpaper_dir"
			return 1
		fi

		if [[ "$pick_mode" == "true" ]]; then
			if ! command_exists fzf; then
				error "fzf is required for --pick"
				return 1
			fi

			local picker_lines=""
			local file
			local relative
			while IFS= read -r file; do
				relative="${file#"$wallpaper_dir"/}"
				picker_lines+="${relative}"$'\t'"${file}"$'\n'
			done <<<"$wallpaper_list"

			local selected
			selected="$(printf "%s" "$picker_lines" | fzf --delimiter=$'\t' --with-nth=1 --prompt='Wallpaper> ')"
			if [[ -z "$selected" ]]; then
				warn "Wallpaper selection cancelled"
				return 1
			fi

			wallpaper_path="${selected#*$'\t'}"
		elif [[ "$random_mode" == "true" ]]; then
			local total
			local index
			total="$(printf "%s\n" "$wallpaper_list" | awk 'NF { count++ } END { print count }')"
			index=$((RANDOM % total + 1))
			wallpaper_path="$(printf "%s\n" "$wallpaper_list" | awk -v n="$index" 'NR == n { print; exit }')"
		else
			local preferred_default="$wallpaper_dir/plane-wp.png"
			if [[ -f "$preferred_default" ]]; then
				wallpaper_path="$preferred_default"
			else
				wallpaper_path="$(printf "%s\n" "$wallpaper_list" | awk 'NF { print; exit }')"
			fi
		fi
	fi

	if [[ "$dry_run" == "true" ]]; then
		step "Dry run"
		info "Would set wallpaper to: $wallpaper_path"
		return 0
	fi

	if [[ ! -f "$wallpaper_path" ]]; then
		error "Wallpaper not found: $wallpaper_path"
		return 1
	fi

	step "Setting wallpaper"
	info "Using file: $wallpaper_path"
	swaymsg output "*" bg "$wallpaper_path" fill

	# Persist so sway config picks it up on next launch
	local state_dir="$HOME/.local/state/dot"
	mkdir -p "$state_dir"
	printf "%s\n" "$wallpaper_path" >"$state_dir/wallpaper"

	info "Wallpaper set successfully"
	return 0
}

dot_cmd_wallpaper() {
	local action="${1:-set}"
	shift || true

	case "$action" in
	sync)
		dot_wallpaper_sync "$@"
		;;
	list)
		dot_wallpaper_list "$@"
		;;
	set)
		dot_wallpaper_set "$@"
		;;
	-h | --help | help)
		cat <<'EOF'
Usage:
  dot wallpaper sync [--dry-run]
  dot wallpaper list
  dot wallpaper set [path] [--pick|--random] [--dry-run]

Environment:
  DOT_WALLPAPER_REPO   Override repository URL
  DOT_WALLPAPER_DIR    Override local wallpaper directory
EOF
		;;
	*)
		error "Unknown wallpaper action: $action"
		return 1
		;;
	esac
}
