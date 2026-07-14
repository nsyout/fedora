# linux-dotfiles

Personal Linux (Fedora + Sway) dotfiles, managed by a `dot` CLI.

Sibling to [`.dotfiles`](https://github.com/nsyout/dotfiles) (personal macOS)
and [`work-dotfiles`](https://github.com/nsyout/work-dotfiles) (work macOS).
One machine clones one repo — never more than one.

## Quick Start

```sh
git clone git@github.com:nsyout/linux-dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./dot init
```

This will:
1. Configure third-party RPM repos (1Password, Sublime Text, Dropbox)
2. Install packages via `dnf` + Flatpak
3. Clone external zsh plugins
4. Symlink configs from `linux/` into `~/.config/`
5. Deploy `home/` package (`.zshenv`, `.claude/`) into `~/`
6. Configure zsh, git identity, SSH, Firefox
7. Set up fonts, wallpaper, and tmux plugin manager

For manual setup notes from a fresh Fedora install, see [linux/install.md](linux/install.md).

## The `dot` CLI

```sh
dot init [--yes] [--dry-run]                       # Full setup
dot symlink                                        # Symlink configs
dot update                                         # Update packages + configs
dot doctor                                         # Check system health
dot packages sync|check|list                       # Manage packages
dot plugins sync|list                              # Manage external zsh plugins
dot git setup|status|signing ...                   # Configure git
dot ssh configure|status|sync-yubikey-keys ...     # Configure SSH
dot firefox sync [--dry-run] [--yes]               # Deploy Firefox user.js
dot wallpaper sync|list|set [--pick|--random]      # Wallpaper management
dot display add|list                               # Manage kanshi display profiles
dot system                                         # Deploy /etc configs
dot repos                                          # Configure RPM repos + Flathub
dot theme list|current|set|render                  # Switch color theme across apps
dot qa | dot security | dot sast                   # Quality & security checks
dot link | dot unlink | dot edit                   # Utility
```

## Updating

```sh
dot update
```

This will:
- Run `dnf update`
- Sync packages + Flatpak apps
- Update external zsh plugins
- Re-deploy symlinked config directories

Firefox updates are explicit and separate: `dot firefox sync`

## Repo Structure

```
linux-dotfiles/
├── dot                              # CLI entrypoint
├── .claude/                         # Project-level Claude Code settings
│
├── linux/                           # All Linux (Fedora/Sway) configs
│   ├── home/                        # Deployed directly to ~/
│   │   ├── .zshenv                  # Shell environment
│   │   └── .claude/                 # Global Claude Code settings
│   ├── bat/, btop/, ghostty/, git/, nvim/, ripgrep/, starship/, tmux/, zsh/
│   ├── sway/, waybar/, kanshi/, mako/, rofi/, gtk-3.0/, gtk-4.0/
│   ├── firefox/, gallery-dl/, opencode/, opengrep/, ssh/, systemd/, yt-dlp/
│   ├── etc/                         # System configs deployed to /etc
│   ├── packages                     # DNF packages
│   ├── flatpaks                     # Flatpak apps
│   ├── symlink-manifest             # Configs to symlink into ~/.config
│   └── install.md                   # Fresh Fedora setup notes
│
├── scripts/
│   ├── lib/
│   │   ├── common.sh                # Logging, color, command_exists
│   │   ├── platform.sh              # Linux assert + DOT_PLATFORM_DIR
│   │   ├── symlink.sh               # Symlink deployment + home/ tree
│   │   ├── packages.sh              # dnf + Flatpak management
│   │   ├── plugins.sh               # External zsh plugin management
│   │   └── linux/                   # Linux command implementations
│   │       ├── cmd_init.sh, cmd_git.sh, cmd_ssh.sh, cmd_firefox.sh
│   │       ├── cmd_display.sh, cmd_theme.sh, cmd_wallpaper.sh
│   │       ├── cmd_system.sh, cmd_update.sh, cmd_doctor.sh
│   ├── update-tools.sh              # Install/update Ghostty, Starship, etc.
│   ├── check-updates.sh             # DNF update notification via mako
│   ├── rofi-emoji.sh                # Rofi emoji picker
│   ├── rofi-system-menu.sh          # Rofi system menu: theme, power, sway
│   └── local-qa.sh, local-sast.sh, local-security.sh
│
└── themes/                          # Color scheme definitions + rendering
    ├── catppuccin/, everforest/, flexoki-dark/, flexoki-light/
    ├── gruvbox/, kanagawa/, nord/, rose-pine/, tokyo-night/
    ├── templates/                   # Mustache-style render templates
    └── current                      # Active theme name
```

## How It Works

### Config deployment (`dot symlink`)

Two deployment mechanisms:

1. **`home/` tree** -- files in `linux/home/` are symlinked directly into
   `~/`, preserving their directory structure. This handles `.zshenv` and
   `.claude/` settings.

2. **Symlink manifests** -- each config directory listed in
   `linux/symlink-manifest` gets symlinked into `~/.config/`:
   ```
   linux/bat/  -> ~/.config/bat
   linux/sway/ -> ~/.config/sway
   ```

`dot symlink` only deploys source-controlled files from `home/`.
Runtime/package-manager artifact directories (`node_modules/`, `.pnpm/`,
`.cache/`, `dist/`, `build/`, `.turbo/`) are skipped.

Also links `dot` to `~/.local/bin/dot`.

### Package management

Flat text file (`packages`) with one package name per line. Installed via
`dnf`. Some tools (Ghostty, Starship, lazygit) are managed by
`scripts/update-tools.sh` instead. Flatpak apps listed in `flatpaks`.

### External zsh plugins

External plugins are declared in `linux/zsh/plugins/external.txt` and cloned
on `dot init` / `dot update`:

- `zsh-syntax-highlighting` -- command line syntax coloring
- `zsh-completions` -- additional tab completion definitions
- `zsh-you-should-use` -- reminds you of existing aliases

Bundled plugins (`bd`, `fzf-utils`, `smartdots`, `which-key`) are committed
directly.

```sh
dot plugins sync    # clone or update external plugins
dot plugins list    # show install status
```

## SSH (YubiKey Resident Keys)

YubiKey-resident SSH keys (no local software key generation):

```sh
# Download resident key pointers from the inserted YubiKey
dot ssh sync-yubikey-keys --slot primary
dot ssh sync-yubikey-keys --slot backup

# Generate ~/.ssh/config from the dotfiles template
dot ssh configure

# Check YubiKey + pointer key status
dot ssh status
```

## Firefox Configuration

Firefox is configured via `linux/firefox/`:

- **Privacy hardening** via arkenfox user.js (downloaded fresh on setup/sync)
- **Custom overrides** in `user-overrides.js` (session restore, search engine,
  vertical tabs, etc.)
- **Extension policies** in `extensions.conf` -- auto-installs uBlock Origin,
  1Password, and more

```sh
dot firefox sync              # deploy/update firefox config
dot firefox sync --dry-run    # preview changes
```

## Theming

Color themes are defined as TOML files in `themes/`. Running
`dot theme set <name>` renders templates from `themes/templates/` into the
appropriate config files and live-reloads running apps.

```sh
dot theme list      # catppuccin, everforest, flexoki-dark, flexoki-light,
                    # gruvbox, kanagawa, nord, rose-pine, tokyo-night
dot theme set nord
dot theme current
```

Renders into: Ghostty, tmux, Waybar, btop, mako, rofi, Sway. Ghostty requires
a restart; everything else reloads live.

## System Hardening

The `dot system` command deploys these to `/etc`:

- **Kernel** -- sysctl hardening (no kexec, no core dumps, restricted BPF,
  SYN cookies)
- **DNS** -- DNS-over-TLS via systemd-resolved with Quad9 + DNSSEC
- **NTP** -- Chrony with NTS-authenticated servers
- **Fail2ban** -- SSH brute-force protection (3 attempts, 1h ban)
- **SSH** -- Locked to Tailscale interface
- **SELinux** -- Enforcing (Fedora default)
- **Disk** -- LUKS full-disk encryption (configured at install)

## Shell Configuration

**Modular zsh setup** with numbered files in `.zshrc.d/` for ordered loading:

| File | Purpose |
|------|---------|
| `00-env.zsh` | Environment, PATH, editor, fpath |
| `05-settings.zsh` | Zsh options (history, completion, vi mode) |
| `10-aliases.zsh` | Alias loader |
| `20-functions.zsh` | Function loader |
| `30-fzf.zsh` | FZF configuration |
| `40-completion.zsh` | Tab completion styling and caching |
| `90-plugins.zsh` | Starship, zoxide, plugin loading |

**Key aliases**: `dotf` (jump to dotfiles), `pj`/`pjp`/`pjw` (project dirs),
`l`/`ll`/`lt` (eza listings), `dl`/`dt` (Downloads/Desktop)

### Media Download Helpers

The `mediadl` function auto-selects the right downloader based on URL:

```sh
mediadl <url>                    # auto-detect backend
mediadl --audio <url>            # extract audio as MP3
mediadl --playlist <url>         # download playlist
mediadl --social <url>           # force gallery-dl
mediadl                          # interactive fzf picker
```

| Function | Description |
|----------|-------------|
| `mediadl <url>` | Auto-select downloader from URL |
| `ytdlvideo <url>` | Download single video (best quality, mkv) |
| `ytdlplaylist <url>` | Download playlist (numbered, mkv) |
| `ytdlaudio <url>` | Extract audio as MP3 |
| `ytdlarchive <url>` | Archive channel with progress tracking |
| `igdl <url>` | Download Instagram media via gallery-dl |
| `gdl <url>` | Force gallery-dl for any URL |
| `webmirror <url>` | Mirror a site with polite wget defaults |

Instagram, Reddit, X/Twitter, Bluesky, and Pinterest URLs auto-route to
gallery-dl. Video URLs route to yt-dlp. Gallery-dl config supports local
credential overlays via `.config/gallery-dl/config.local.json` (gitignored).

### noisyoutput.com Content Management

The `nsy` function manages Hugo content for noisyoutput.com:

```sh
nsy              # interactive menu
nsy create       # create new content (note, writing, page)
nsy manage       # edit, delete, publish, unpublish existing content
nsy sync         # commit and push staged changes
```

## Quality & Security

```sh
dot qa                           # shellcheck, shfmt, gitleaks, config parsing
dot security [--history]         # secret scanning (add --history for git log)
dot sast [--strict]              # static analysis via opengrep
```

Install pre-commit hook:

```sh
ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
```

## Troubleshooting

### Missing commands after install

```sh
source ~/.zshenv
source ~/.config/zsh/.zshrc
# or just:
exec zsh
```

### Symlink conflicts

`dot symlink` detects existing non-symlink files and either skips them
(default) or replaces them (`--yes`). If you hit conflicts:

```sh
dot symlink --yes          # auto-replace conflicting files
# or manually:
rm -rf ~/.config/someapp
dot symlink
```

### Slow prompt

Starship should render in under 200ms. If slow:

```sh
time zsh -i -c exit     # time shell startup
which starship          # verify it's installed
```

### External plugins not loading

```sh
dot plugins list        # check install status
dot plugins sync        # clone missing plugins
```
