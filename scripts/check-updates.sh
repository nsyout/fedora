#!/bin/bash
# Check for available dnf updates and notify via mako/notify-send

count=$(dnf check-upgrade --quiet 2>/dev/null | grep -cE '^\S+\.\S+\s')

if [ "$count" -gt 0 ]; then
    notify-send \
        --urgency=critical \
        --app-name="Updates" \
        "System Updates Available" \
        "$count package(s) can be updated.\nRun: sudo dnf update"
fi
