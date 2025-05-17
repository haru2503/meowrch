#!/bin/bash

# Lấy title và artist
title=$(playerctl metadata title 2>/dev/null)
artist=$(playerctl metadata artist 2>/dev/null)

if [ -z "$title" ]; then
  # Không có nhạc
  echo '{"text": "  No media", "tooltip": ""}'
  exit 0
fi

# Rút gọn title nếu dài hơn 20 ký tự
short_title=$title
if [ ${#title} -gt 20 ]; then
  short_title="${title:0:20}..."
fi

# Trả về JSON
echo "{\"text\": \"  $short_title\", \"tooltip\": \"$artist - $title\"}"