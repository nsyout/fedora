#!/usr/bin/env zsh

# Prompt - Starship (fast Rust-based prompt)
eval "$(starship init zsh)"

# zoxide
eval "$(zoxide init zsh)"

# Plugin loading - order matters for some plugins

# Load utility plugins first
safe_source "$ZDOTDIR/plugins/bd/bd.zsh"
safe_source "$ZDOTDIR/plugins/smartdots/smartdots.zsh"
safe_source "$ZDOTDIR/plugins/which-key/which-key.zsh"

# External plugins (cloned by dot init / dot update)
safe_source "$ZDOTDIR/plugins/zsh-completions/zsh-completions.plugin.zsh"
safe_source "$ZDOTDIR/plugins/zsh-you-should-use/you-should-use.plugin.zsh"

# Syntax highlighting - must be last
safe_source "$ZDOTDIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
