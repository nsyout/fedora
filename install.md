# Sway Desktop Environment Setup

Fresh Fedora 43 minimal (net install) with Sway.

## Base Install

These should already be present from the Fedora Sway spin or initial setup:

```sh
sudo dnf install sway sway-config-fedora swaybg swayidle swaylock sway-systemd \
    foot rofi waybar grim slurp grimshot wl-clipboard pipewire wireplumber
```

## Ghostty (terminal emulator, built from source)

```sh
# Build deps
sudo dnf install zig gtk4-devel gtk4-layer-shell-devel libadwaita-devel gettext

# Download tip source tarball (NOT the GitHub auto-generated "Source code" archive)
curl -LO https://github.com/ghostty-org/ghostty/releases/download/tip/ghostty-source.tar.gz
tar -xf ghostty-source.tar.gz
cd ghostty-*

# Build and install to ~/.local
zig build -Doptimize=ReleaseFast -p $HOME/.local
```

## Additional Packages

```sh
sudo dnf install mako brightnessctl playerctl pavucontrol \
    network-manager-applet xdg-desktop-portal-wlr blueman
```

| Package | Purpose |
|---------|---------|
| mako | Notification daemon (Wayland-native) |
| brightnessctl | Backlight control from keybinds |
| playerctl | Media key support (MPRIS) |
| pavucontrol | PulseAudio/PipeWire volume GUI |
| network-manager-applet | NetworkManager tray applet (nm-applet) |
| xdg-desktop-portal-wlr | Screen sharing support for Sway |
| blueman | Bluetooth manager with tray applet |

## Dotfiles Setup

### Symlink configs into place

```sh
# Remove any existing configs (back up first if needed)
rm -rf ~/.config/sway ~/.config/mako ~/.config/waybar

# Create symlinks
ln -s ~/.dotfiles/sway ~/.config/sway
ln -s ~/.dotfiles/mako ~/.config/mako
ln -s ~/.dotfiles/waybar ~/.config/waybar
ln -s ~/.dotfiles/ghostty ~/.config/ghostty
ln -s ~/.dotfiles/gtk-3.0 ~/.config/gtk-3.0
ln -s ~/.dotfiles/gtk-4.0 ~/.config/gtk-4.0
mkdir -p ~/.config/systemd/user
ln -s ~/.dotfiles/systemd/user/check-updates.service ~/.config/systemd/user/
ln -s ~/.dotfiles/systemd/user/check-updates.timer ~/.config/systemd/user/
```

## Config Structure

```
~/.dotfiles/
├── install.md                              # This file
├── ghostty/
│   └── config                              # Terminal font size, appearance
├── gtk-3.0/
│   └── settings.ini                        # GTK3 dark theme + font + cursor
├── gtk-4.0/
│   └── settings.ini                        # GTK4 dark theme + font + cursor
├── sway/
│   ├── config                              # Main sway config (based on Fedora defaults)
│   ├── environment                         # Env vars (GTK_THEME, QT, Java)
│   └── config.d/
│       ├── 50-rules-browser.conf           # Fullscreen browser inhibits idle
│       ├── 50-rules-pavucontrol.conf       # Pavucontrol floats centered
│       ├── 50-rules-policykit-agent.conf   # Polkit agent floats centered
│       ├── 60-bindings-brightness.conf     # XF86 brightness keys → brightnessctl
│       ├── 60-bindings-media.conf          # XF86 media keys → playerctl
│       ├── 60-bindings-screenshot.conf     # Print/Alt+Print/Ctrl+Print → grimshot
│       ├── 60-bindings-volume.conf         # XF86 volume keys → pactl
│       ├── 65-mode-passthrough.conf        # Mod+Pause → passthrough mode
│       ├── 70-bindings-custom.conf         # Custom keybinds (lock screen, etc.)
│       ├── 90-bar.conf                     # Waybar as status bar
│       ├── 90-swayidle.conf                # Idle/lock timeout config
│       ├── 95-autostart-custom.conf        # Start mako
│       ├── 95-autostart-policykit-agent.conf
│       ├── 95-xdg-desktop-autostart.conf   # XDG autostart (nm-applet, blueman, etc.)
│       └── 95-xdg-user-dirs.conf
├── scripts/
│   └── check-updates.sh                    # Daily dnf update check → notification
├── systemd/
│   └── user/
│       ├── check-updates.service           # Oneshot service for update check
│       └── check-updates.timer             # Daily timer with random delay
├── etc/
│   ├── fail2ban/
│   │   └── jail.local                       # Fail2ban config (sshd, 3 attempts, 1h ban)
│   ├── sysctl.d/
│   │   └── 90-hardening.conf               # Kernel sysctl hardening
│   └── systemd/
│       └── resolved.conf.d/
│           └── quad9.conf                   # DNS-over-TLS with Quad9
├── mako/
│   └── config                              # Notification daemon settings
└── waybar/
    ├── config.jsonc                        # Bar layout and modules
    └── style.css                           # Bar styling
```

## Theming

- GTK 3 & 4: Adwaita-dark via `settings.ini`
- Sway cursor: Adwaita 24px via `seat seat0 xcursor_theme`
- Env vars in `sway/environment`: `GTK_THEME=Adwaita:dark`, `QT_QPA_PLATFORMTHEME=gtk3`
- Font: Noto Sans 11pt for GTK apps

## Waybar

Modules (left to right): workspaces, mode, scratchpad | window title | idle inhibitor, volume, network, bluetooth, cpu, memory, temperature, clock, tray

- Click volume module → opens pavucontrol
- Click bluetooth module → opens blueman-manager
- Click clock → toggles date format
- Idle inhibitor toggle → prevents screen lock when active

Stripped from Fedora defaults: battery, backlight, power-profiles-daemon, mpd, custom/media, custom/power (not needed on desktop).

## Security

### Tailscale

```sh
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up
```

### SSH locked to Tailscale

Drop-in config at `/etc/ssh/sshd_config.d/99-tailscale.conf`:

```
ListenAddress 100.96.1.7
PermitRootLogin no
MaxAuthTries 3
```

```sh
sudo systemctl restart sshd
```

### Firewall

Fedora ships firewalld active with `public` zone. After moving SSH to Tailscale, remove it from the public zone:

```sh
sudo firewall-cmd --zone=public --remove-service=ssh --permanent
sudo firewall-cmd --reload
```

Remaining public zone services: `dhcpv6-client`, `mdns`.

### Update notifications

A systemd user timer runs daily, checks for available dnf updates, and sends a desktop notification via notify-send/mako if any are found.

```sh
# Symlink units
mkdir -p ~/.config/systemd/user
ln -s ~/.dotfiles/systemd/user/check-updates.service ~/.config/systemd/user/
ln -s ~/.dotfiles/systemd/user/check-updates.timer ~/.config/systemd/user/

# Enable
systemctl --user daemon-reload
systemctl --user enable --now check-updates.timer
```

### CPU microcode

```sh
sudo dnf install amd-ucode-firmware
```

Patches CPU hardware vulnerabilities. Applied on next boot.

### Kernel sysctl hardening

Config stored in dotfiles at `etc/sysctl.d/90-hardening.conf`. Install with:

```sh
sudo cp ~/.dotfiles/etc/sysctl.d/90-hardening.conf /etc/sysctl.d/90-hardening.conf
sudo sysctl --system
```

Hardens: kernel pointer hiding, kexec disabled, core dumps disabled, BPF restricted,
network (SYN cookies, reverse path filtering, no ICMP redirects, no TCP timestamps),
symlink/hardlink protection.

### DNS-over-TLS (Quad9)

Config stored in dotfiles at `etc/systemd/resolved.conf.d/quad9.conf`. Install with:

```sh
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo cp ~/.dotfiles/etc/systemd/resolved.conf.d/quad9.conf /etc/systemd/resolved.conf.d/quad9.conf
sudo systemctl restart systemd-resolved
```

Uses Quad9 (9.9.9.9 / 149.112.112.112) with DNS-over-TLS and DNSSEC validation.
Verify with: `resolvectl status`

### Fail2ban

```sh
sudo dnf install fail2ban
sudo cp ~/.dotfiles/etc/fail2ban/jail.local /etc/fail2ban/jail.local
sudo systemctl enable --now fail2ban
```

Bans IPs after 3 failed auth attempts for 1 hour. Watches sshd.

### OpenSnitch (outbound firewall)

Download RPMs from https://github.com/evilsocket/opensnitch/releases

```sh
sudo dnf install ./opensnitch-*.x86_64.rpm ./opensnitch-ui-*.noarch.rpm
sudo systemctl enable --now opensnitch
```

Prompts to allow/deny outbound connections per-application. Launch UI with `opensnitch-ui`.

### Idle lock timeout

Set to 10 minutes (lock) + 1 minute (screen off after lock) via `$lock_timeout` and
`$screen_timeout` variables in sway config. Swayidle picks these up from `90-swayidle.conf`.

### SELinux

Enforcing (Fedora default). Don't disable it.

### Disk encryption

LUKS full-disk encryption configured at install time.

### Notes for laptop reuse

**USBGuard** — consider installing for laptop deployments where physical access is less controlled.
Whitelists known USB devices, blocks new ones until approved. Install with `sudo dnf install usbguard`,
generate initial policy with `sudo usbguard generate-policy > /etc/usbguard/rules.conf`,
then `sudo systemctl enable --now usbguard`. New devices approved via `usbguard allow-device`.

## Key Bindings Reference

| Binding | Action |
|---------|--------|
| Mod+Return | Terminal (ghostty) |
| Mod+d | App launcher (rofi) |
| Mod+w | Kill window |
| Mod+Shift+c | Reload sway config |
| Mod+Shift+e | Exit sway |
| Mod+Shift+Escape | Lock screen |
| Mod+n | Dismiss notification |
| Mod+Shift+n | Dismiss all notifications |
| Mod+h/j/k/l | Focus left/down/up/right |
| Mod+Shift+h/j/k/l | Move window |
| Mod+1-0 | Switch workspace 1-10 |
| Mod+Shift+1-0 | Move window to workspace |
| Mod+b / Mod+v | Split horizontal / vertical |
| Mod+e | Toggle split direction |
| Mod+f | Fullscreen |
| Mod+Shift+Space | Toggle floating |
| Mod+Space | Toggle focus tiling/floating |
| Mod+r | Resize mode (h/j/k/l or arrows) |
| Mod+Shift+Minus | Move to scratchpad |
| Mod+Minus | Show scratchpad |
| Mod+Pause | Passthrough mode |
| Print | Screenshot (full output) |
| Alt+Print | Screenshot (active window) |
| Ctrl+Print | Screenshot (select area) |
| XF86Audio* | Volume up/down/mute |
| XF86MonBrightness* | Brightness up/down |
| XF86Audio Play/Next/Prev | Media controls |
