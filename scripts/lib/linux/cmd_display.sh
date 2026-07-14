#!/usr/bin/env bash

dot_cmd_display() {
	local action="${1:-help}"
	shift || true

	case "$action" in
	add)
		dot_display_add "$@"
		;;
	list)
		dot_display_list "$@"
		;;
	-h | --help | help)
		cat <<'EOF'
Usage: dot display <command>

Commands:
  add      Detect connected displays and add missing kanshi profiles
  list     Show current kanshi profiles
EOF
		;;
	*)
		error "Unknown display command: $action"
		echo "Run 'dot display help' for usage."
		return 1
		;;
	esac
}

dot_display_list() {
	local kanshi_config="$DOT_PLATFORM_DIR/kanshi/config"

	if [[ ! -f "$kanshi_config" ]]; then
		warn "No kanshi config found at $kanshi_config"
		return 1
	fi

	info "Kanshi profiles:"
	echo ""
	awk '/^profile / { name=$2 } /output / && name { print "  " name ": " $0 }' "$kanshi_config"
}

dot_display_add() {
	local kanshi_config="$DOT_PLATFORM_DIR/kanshi/config"
	local dry_run=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			dry_run=true
			;;
		-h | --help)
			cat <<'EOF'
Usage: dot display add [--dry-run]

Detects connected displays and prompts to add kanshi profiles
for any that don't already have one.

Options:
  --dry-run    Show what would be added without writing
EOF
			return 0
			;;
		*)
			error "Unknown option: $1"
			return 1
			;;
		esac
		shift
	done

	if ! command_exists swaymsg; then
		error "swaymsg not found — are you running Sway?"
		return 1
	fi

	if ! command_exists jq; then
		error "jq not found — install it with: dnf install jq"
		return 1
	fi

	# Get connected outputs
	local outputs
	outputs="$(swaymsg -t get_outputs -r)" || {
		error "Failed to query Sway outputs. Is Sway running?"
		return 1
	}

	local count
	count="$(echo "$outputs" | jq 'length')"

	if [[ "$count" -eq 0 ]]; then
		warn "No outputs detected."
		return 0
	fi

	local added=0

	for i in $(seq 0 $((count - 1))); do
		local make model serial resolution scale name
		make="$(echo "$outputs" | jq -r ".[$i].make")"
		model="$(echo "$outputs" | jq -r ".[$i].model")"
		serial="$(echo "$outputs" | jq -r ".[$i].serial")"
		resolution="$(echo "$outputs" | jq -r ".[$i].current_mode | \"\(.width)x\(.height)\"")"
		scale="$(echo "$outputs" | jq -r ".[$i].scale")"
		name="$(echo "$outputs" | jq -r ".[$i].name")"

		local identifier="$make $model $serial"

		# Check if this output already has a kanshi profile
		if [[ -f "$kanshi_config" ]] && grep -qF "\"$identifier\"" "$kanshi_config"; then
			info "Already configured: $identifier ($resolution)"
			continue
		fi

		echo ""
		info "New display detected:"
		echo "  Output:     $name"
		echo "  Display:    $make $model"
		echo "  Serial:     $serial"
		echo "  Resolution: $resolution"
		echo "  Current:    scale $scale"
		echo ""

		# Suggest a scale based on resolution
		local width
		width="$(echo "$outputs" | jq -r ".[$i].current_mode.width")"
		local suggested_scale="1"
		if [[ "$width" -ge 3840 ]]; then
			suggested_scale="1.5"
		elif [[ "$width" -ge 2560 ]]; then
			suggested_scale="1.5"
		fi

		local chosen_scale
		read -rp "  Scale factor [$suggested_scale]: " chosen_scale
		chosen_scale="${chosen_scale:-$suggested_scale}"

		# Suggest a profile name
		local suggested_name
		suggested_name="$(echo "$model" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')"
		[[ -z "$suggested_name" ]] && suggested_name="display-$name"

		local profile_name
		read -rp "  Profile name [$suggested_name]: " profile_name
		profile_name="${profile_name:-$suggested_name}"

		local entry
		entry=$(
			cat <<EOF

# $make $model — $resolution
profile $profile_name {
    output "$identifier" scale $chosen_scale
}
EOF
		)

		if $dry_run; then
			info "Would add:"
			echo "$entry"
		else
			echo "$entry" >>"$kanshi_config"
			info "Added profile '$profile_name' (scale $chosen_scale)"
			((added++))
		fi
	done

	if [[ "$added" -gt 0 ]]; then
		echo ""
		info "Added $added profile(s) to $kanshi_config"
		info "Reload kanshi to apply: swaymsg reload"
	elif ! $dry_run; then
		info "All displays already configured."
	fi
}
