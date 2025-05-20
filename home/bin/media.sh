#!/bin/bash

# Escape JSON safely
json_escape() {
  echo -n "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# Escape for GTK markup
html_escape() {
  echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\"/\&quot;/g; s/'"'"'/\&#39;/g'
}

# Truncate safely
truncate_text() {
  local text="$1"
  local max_length="$2"
  if [ ${#text} -gt $max_length ]; then
    echo "${text:0:max_length}…"
  else
    echo "$text"
  fi
}

# Normalize for comparison
normalize() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/([^)]*)//g' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# Lấy metadata
title=$(playerctl metadata title 2>/dev/null)
artist=$(playerctl metadata artist 2>/dev/null)

# Nếu không có title, thoát sớm
if [ -z "$title" ]; then
  echo '{"text": "  No media", "tooltip": ""}'
  exit 0
fi

# Tìm xem title có chứa phân cách không
if [[ "$title" == *"｜"* || "$title" == *"|"* || "$title" == *"-"* ]]; then
  # Tách theo dấu phân cách
  if [[ "$title" == *"｜"* ]]; then
    IFS='｜' read -r part1 part2 <<< "$title"
  elif [[ "$title" == *"|"* ]]; then
    IFS='|' read -r part1 part2 <<< "$title"
  else
    IFS='-' read -r part1 part2 <<< "$title"
  fi

  part1=$(echo "$part1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  part2=$(echo "$part2" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  # Normalize để so với metadata artist
  norm_part1=$(normalize "$part1")
  norm_part2=$(normalize "$part2")
  norm_artist=$(normalize "$artist")

  # So sánh độ giống
  if [[ "$norm_part1" == "$norm_artist"* ]]; then
    artist="$part1"
    title="$part2"
  elif [[ "$norm_part2" == "$norm_artist"* ]]; then
    artist="$part2"
    title="$part1"
  else
    # Nếu không rõ thì giữ nguyên thứ tự, part1 là artist
    artist="$part2"
    title="$part1"
  fi
else
  # Nếu không có dấu phân cách và artist vẫn trống → để nguyên title, artist rỗng
  if [ -z "$artist" ]; then
    artist=""
  fi
fi

# Nếu vẫn không rõ artist, dùng fallback cũ
if [ -z "$artist" ]; then
  if [[ "$title" == *"｜"* ]]; then
    artist=$(echo "$title" | awk -F '｜' '{print $1}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    title=$(echo "$title" | awk -F '｜' '{$1=""; sub(/^ /,""); print}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  elif [[ "$title" == *"-"* ]]; then
    artist=$(echo "$title" | awk -F '-' '{print $1}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    title=$(echo "$title" | awk -F '-' '{$1=""; sub(/^ /,""); print}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  fi
fi

# Tạo text hiển thị
if [ -n "$artist" ]; then
  short_title=$(truncate_text "$title" 15)
  short_artist=$(truncate_text "$artist" 10)
  display_text="  $short_title | $short_artist"
else
  short_title=$(truncate_text "$title" 25)
  display_text="  $short_title"
fi

# Escape và xuất
escaped_display=$(html_escape "$display_text")
escaped_tooltip=$(json_escape "$title — $artist")

echo "{\"text\": \"$escaped_display\", \"tooltip\": $escaped_tooltip}"
