#
# Consolidated Aliases (Linux)
#

# Utility function for checking command existence
_exists() {
  command -v $1 > /dev/null 2>&1
}

# ------------------------------------------------------------------------------
# System Utilities
# ------------------------------------------------------------------------------

# Enable aliases to be sudo'ed
alias sudo='sudo '

# Clear shortcuts
alias clr='clear'
alias q="cd ~ && clear"

# Commands
alias e='$EDITOR'
alias x+='chmod +x'

# Show $PATH in readable view
alias path='echo -e ${PATH//:/\\n}'

# ------------------------------------------------------------------------------
# Directory Navigation
# ------------------------------------------------------------------------------

# Folder shortcuts (system directories)
[ -d ~/Downloads ] && alias dl='cd ~/Downloads' || [ -d ~/downloads ] && alias dl='cd ~/downloads'
[ -d ~/Desktop ]   && alias dt='cd ~/Desktop'   || [ -d ~/desktop ]   && alias dt='cd ~/desktop'

# Personal project directories
[ -d ~/projects ]             && alias pj='cd ~/projects'
[ -d ~/projects/personal ]    && alias pjp='cd ~/projects/personal'
[ -d ~/projects/work ]        && alias pjw='cd ~/projects/work'
[ -d ~/projects/external ]    && alias pje='cd ~/projects/external'

# Directory stack shortcuts
alias d='dirs -v'

# ------------------------------------------------------------------------------
# Dotfiles Management
# ------------------------------------------------------------------------------

alias dotf='cd ~/.dotfiles'

# ------------------------------------------------------------------------------
# File Operations
# ------------------------------------------------------------------------------

# ls with eza fallback
if _exists eza; then
  alias ls >/dev/null 2>&1 && unalias ls
  alias ls='eza'
  alias lt='eza --tree'
  alias l='ls'
  alias ll='eza -la --git'
  alias lt1='eza --tree --level=1'
  alias lt2='eza --tree --level=2'
  alias lt3='eza --tree --level=3'
else
  alias ls='ls --color=auto'
  alias l='ls'
  alias ll='ls -la --color=auto'
fi

# Keep original rm available when needed
alias rmi='command rm -i'  # Interactive rm
alias rmf='command rm -f'  # Force rm

# NCDU disk usage analyzer
if _exists ncdu; then
  alias diskusage='ncdu --color dark -rr -x --exclude .git --exclude node_modules'
fi

# ------------------------------------------------------------------------------
# Network & Web
# ------------------------------------------------------------------------------

# My IP address
alias myip='ip addr | sed -En "s/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p"'

# Download utilities
alias getpage='wget --no-clobber --page-requisites --html-extension --convert-links --no-host-directories'
alias get="curl -O -L"

# ------------------------------------------------------------------------------
# Development Tools
# ------------------------------------------------------------------------------

alias oc='opencode .'

# Check git status across subdirectories (usage: repostatus [dir])
repostatus() {
  local base_dir="${1:-.}"
  for dir in "$base_dir"/*/; do
    [ -d "$dir/.git" ] || continue
    local name="${dir%/}"
    [ -n "$(git -C "$dir" log @{u}.. 2>/dev/null)" ] && echo "[PUSH] $name"
    [ -n "$(git -C "$dir" status --porcelain)" ] && echo "[DIRTY] $name"
  done
}

# Help/documentation
if _exists tldr; then
  alias help="tldr"
fi
