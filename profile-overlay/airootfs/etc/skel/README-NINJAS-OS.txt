Welcome to Ninjas OS (Alpha)

This is an experimental Arch-based live image built by the Ninjas OS project.
Everything you change in this live session is lost on reboot.

- Image metadata:        cat /etc/ninjas-os-release
- Service health:        systemctl --failed
- Boot warnings:         journalctl -b -p warning
- Network:               nmcli device status

The AI assistant is not part of this release. When it arrives it will run as
an unprivileged user-space application behind a deny-by-default policy engine.
