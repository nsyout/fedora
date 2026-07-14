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

# Check if a new Fedora major release is available
current_ver=$(. /etc/os-release && echo "$VERSION_ID")
next_ver=$((current_ver + 1))
if curl -sf --head --max-time 5 \
	"https://dl.fedoraproject.org/pub/fedora/linux/releases/${next_ver}/" \
	-o /dev/null 2>/dev/null; then
	notify-send \
		--urgency=critical \
		--app-name="Fedora" \
		"Fedora ${next_ver} Available" \
		"Upgrade: sudo dnf system-upgrade download --releasever=${next_ver}"
fi
