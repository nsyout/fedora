#!/usr/bin/env zsh

# fzf configuration

# Flexoki Dark theme
export FZF_DEFAULT_OPTS="
  --color=bg:#100F0F,bg+:#1C1B1A,fg:#CECDC3,fg+:#CECDC3
  --color=hl:#DA702C,hl+:#D0A215,info:#878580,marker:#879A39
  --color=prompt:#4385BE,spinner:#CE5D97,pointer:#CE5D97,header:#DA702C
  --color=border:#575653,label:#CECDC3,query:#CECDC3
"

# Source fzf shell integration (Fedora)
if command -v fzf &>/dev/null; then
    source <(fzf --zsh)
fi

# fzf utilities
[[ -f "$ZDOTDIR/plugins/fzf-utils/fzf-utils.zsh" ]] && source "$ZDOTDIR/plugins/fzf-utils/fzf-utils.zsh"
