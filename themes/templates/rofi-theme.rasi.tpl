@theme "/dev/null"

* {
  bg:               {{ background }};
  bg-panel:         {{ panel_background }};
  bg-alt:           {{ muted_background }};
  fg:               {{ foreground }};
  fg-muted:         {{ muted_foreground }};
  accent:           {{ accent }};
  accent-2:         {{ accent_2 }};
  accent-3:         {{ accent_3 }};
  urgent:           {{ urgent }};
  border:           {{ border }};
  background-color: @bg;
  text-color:       @fg;
}

window {
  anchor: center;
  location: center;
  width: 42%;
  padding: 24px;
  border: 1px;
  border-color: @border;
  border-radius: 18px;
  background-color: @bg-panel;
}

mainbox {
  spacing: 18px;
  background-color: transparent;
  children: [ inputbar, message, listview ];
}

inputbar {
  children: [ prompt, entry ];
  spacing: 14px;
  padding: 14px 18px;
  border: 1px;
  border-color: @border;
  border-radius: 14px;
  background-color: @bg-alt;
}

prompt {
  enabled: true;
  background-color: transparent;
  text-color: @accent-2;
}

entry {
  placeholder: "Search apps, commands, and windows";
  placeholder-color: @fg-muted;
  background-color: transparent;
  text-color: @fg;
}

message {
  enabled: false;
}

listview {
  lines: 8;
  columns: 1;
  fixed-height: false;
  dynamic: true;
  cycle: false;
  spacing: 10px;
  scrollbar: false;
  background-color: transparent;
}

element {
  orientation: horizontal;
  spacing: 14px;
  padding: 12px 14px;
  border-radius: 14px;
  background-color: transparent;
  text-color: @fg;
}

element selected.normal {
  background-color: @bg-alt;
  text-color: @fg;
}

element-icon {
  size: 28px;
  vertical-align: 0.5;
  background-color: transparent;
}

element-text {
  vertical-align: 0.5;
  background-color: transparent;
  text-color: inherit;
}
