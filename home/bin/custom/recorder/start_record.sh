#!/bin/bash
FILENAME=~/Videos/Recordings/record_$(date +%s).mkv
wf-recorder -g "$(slurp)" -f "$FILENAME" &
echo $! > /tmp/wf-recorder.pid
notify-send "🎥 Screen recording started!"
