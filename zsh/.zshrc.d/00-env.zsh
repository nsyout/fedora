#!/usr/bin/env zsh

fpath=($ZDOTDIR/plugins $fpath)

# Starship config location
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

# Default editor for local and remote sessions
if [[ -n "$SSH_CONNECTION" ]]; then
  # on the server
  if command -v vim >/dev/null 2>&1; then
    export EDITOR='vim'
  else
    export EDITOR='vi'
  fi
else
  export EDITOR='nvim'
fi
