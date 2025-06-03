#!/bin/bash
if [ -f /tmp/wf-recorder.pid ]; then
  PID=$(cat /tmp/wf-recorder.pid)
  kill $PID
  rm /tmp/wf-recorder.pid
  notify-send "🎥 Screen recording stopped!"
else
  notify-send "No recording process found."
fi
