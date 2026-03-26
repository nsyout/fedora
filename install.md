# Sway Desktop Environment Setup

Fresh Fedora 43 minimal (net install) with Sway.

## Base Install

These should already be present from the Fedora Sway spin or initial setup:

```sh
sudo dnf install sway sway-config-fedora swaybg swayidle swaylock sway-systemd \
    foot rofi waybar grim slurp grimshot wl-clipboard pipewire wireplumber
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
```

## Config Structure

```
~/.dotfiles/
├── install.md                              # This file
├── sway/
│   ├── config                              # Main sway config (based on Fedora defaults)
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
├── mako/
│   └── config                              # Notification daemon settings
└── waybar/
    ├── config                              # Bar layout and modules (TODO)
    └── style.css                           # Bar styling (TODO)
```

## Key Bindings Reference

| Binding | Action |
|---------|--------|
| Mod+Return | Terminal (foot) |
| Mod+d | App launcher (rofi) |
| Mod+Shift+q | Kill window |
| Mod+Shift+c | Reload sway config |
| Mod+Shift+e | Exit sway |
| Mod+Shift+Escape | Lock screen |
| Mod+h/j/k/l | Focus left/down/up/right |
| Mod+Shift+h/j/k/l | Move window |
| Mod+1-0 | Switch workspace 1-10 |
| Mod+Shift+1-0 | Move window to workspace |
| Mod+b / Mod+v | Split horizontal / vertical |
| Mod+s / Mod+w / Mod+e | Stacking / tabbed / toggle split |
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
