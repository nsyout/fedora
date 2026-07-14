sort=-time
layer=overlay
anchor=top-right
margin=16,16,0
padding=14
width=360
height=140
border-size=1
border-radius=14
icons=1
max-icon-size=48
default-timeout=7000
ignore-timeout=1
background-color={{ panel_background }}
text-color={{ foreground }}
border-color={{ border }}
progress-color=over {{ muted_background }}

[urgency=low]
border-color={{ accent }}

[urgency=normal]
border-color={{ accent_2 }}

[urgency=high]
border-color={{ urgent }}
default-timeout=0
