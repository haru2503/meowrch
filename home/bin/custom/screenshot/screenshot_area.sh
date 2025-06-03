#!/bin/bash
mkdir -p "$HOME/Pictures/Screenshots"
file="$HOME/Pictures/Screenshots/screenshot_$(date +%s).png"
grim -g "$(slurp)" "$file" && wl-copy < "$file" && notify-send "📸 Screenshot (selected area) saved & copied."
