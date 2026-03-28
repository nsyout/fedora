#!/bin/bash
# Emoji picker for rofi — copies selection to clipboard
# Requires: wl-copy

EMOJI_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/rofi/emoji.txt"

if [[ ! -f "$EMOJI_FILE" ]]; then
	mkdir -p "$(dirname "$EMOJI_FILE")"
	curl -sL "https://raw.githubusercontent.com/muan/emojilib/main/dist/emoji-en-US.json" |
		python3 -c "
import json, sys
data = json.load(sys.stdin)
for emoji, keywords in data.items():
    print(f'{emoji} {\" \".join(keywords)}')
" >"$EMOJI_FILE"
fi

selection=$(rofi -dmenu -i -p "Emoji" <"$EMOJI_FILE")
[[ -z "$selection" ]] && exit 0

emoji="${selection%% *}"
printf "%s" "$emoji" | wl-copy
