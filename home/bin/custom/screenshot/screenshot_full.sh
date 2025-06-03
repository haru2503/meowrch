#!/bin/bash
mkdir -p "$HOME/Pictures/Screenshots"
file="$HOME/Pictures/Screenshots/screenshot_$(date +%s).png"
grim "$file" && wl-copy < "$file" && notify-send "📸 Screenshot saved and copied."
