* {
  border: none;
  border-radius: 0;
  font-family: "IosevkaTerm Nerd Font", "Noto Sans Mono", monospace;
  font-size: 13px;
  min-height: 0;
}

window#waybar {
  background: {{ panel_background }};
  border-bottom: 1px solid {{ border }};
  color: {{ foreground }};
}

.modules-left,
.modules-center,
.modules-right {
  margin: 0;
}

#workspaces,
#mode,
#window,
#clock,
#cpu,
#memory,
#temperature,
#pulseaudio,
#network,
#bluetooth,
#battery,
#idle_inhibitor,
#scratchpad,
#tray {
  background: transparent;
  color: {{ foreground }};
  padding: 0 12px;
}

#workspaces button {
  background: transparent;
  border-radius: 0;
  color: {{ muted_foreground }};
  padding: 0 8px;
  border-bottom: 2px solid transparent;
}

#workspaces button.focused {
  color: {{ accent_2 }};
  border-bottom: 2px solid {{ accent_2 }};
}

#workspaces button.urgent,
#battery.warning,
#battery.critical,
#pulseaudio.muted,
#network.disconnected {
  color: {{ urgent }};
}

#clock {
  color: {{ accent }};
}

#mode {
  color: {{ accent_3 }};
}

#window {
  color: {{ subdued_foreground }};
}
