#!/bin/bash

# Escape JSON safely with fallback
json_escape() {
  local input="$1"
  
  # First try with python
  local result
  result=$(echo -n "$input" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null)
  
  if [ $? -eq 0 ] && [ -n "$result" ] && [ "$result" != "null" ]; then
    echo "$result"
    return 0
  fi
  
  # Fallback: manual escaping
  echo -n "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g' | awk '{printf "\"%s\"", $0}'
}

# Escape for GTK markup (order matters - & must be first!)
html_escape() {
  echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
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

# Extract artist and title using pattern recognition
extract_artist_title() {
  local input="$1"
  local best_artist=""
  local best_title=""
  local best_score=0
  
  # Common patterns with scoring
  declare -a patterns=(
    # Japanese style: 【artist】title
    's/^【([^】]+)】\s*(.+?)(\s*\([^)]*\))?\s*(\[.*\])?\s*$/\1|\2/'
    # Full-width Japanese pipe: artist ｜ title
    's/^([^｜]+)\s*｜\s*([^｜]+)$/\1|\2/'
    # Regular pipe: artist | title
    's/^([^|]+)\s*\|\s*([^|]+)$/\1|\2/'
    # Square brackets at start: [artist] title
    's/^\[([^\]]+)\]\s*(.+?)(\s*\([^)]*\))?\s*$/\1|\2/'
    # Artist feat. pattern: artist feat. other - title
    's/^([^-]+(?:feat\.|ft\.|featuring)[^-]*)\s*-\s*(.+)$/\1|\2/'
    # Dash with context (avoid splitting numbers): artist - title
    's/^([^-]{4,}?)\s*-\s*([^-]{4,}.*?)(\s*\([^)]*\))?\s*$/\1|\2/'
    # Parentheses: (artist) title or title (artist) - be careful with feat.
    's/^\(([^)]+)\)\s*(.+?)(\s*\[.*\])?\s*$/\1|\2/'
    's/^(.+?)\s*\(([^)]+)\)(\s*\[.*\])?\s*$/\2|\1/'
    # Artist & Artist - Title pattern
    's/^([^-]+\s*&\s*[^-]+)\s*-\s*(.+)$/\1|\2/'
    # Multiple artist separator: artist, artist - title
    's/^([^-]+,\s*[^-]+)\s*-\s*(.+)$/\1|\2/'
  )
  
  for pattern in "${patterns[@]}"; do
    local result
    result=$(echo "$input" | sed -E "$pattern" 2>/dev/null)
    
    if [[ "$result" == *"|"* ]] && [[ "$result" != "$input" ]]; then
      local artist_candidate="${result%|*}"
      local title_candidate="${result#*|}"
      
      # Clean up
      artist_candidate=$(echo "$artist_candidate" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      title_candidate=$(echo "$title_candidate" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      
      # Skip if either part is too short or empty
      if [[ ${#artist_candidate} -lt 2 || ${#title_candidate} -lt 2 ]]; then
        continue
      fi
      
      # Calculate score based on various factors
      local score=0
      
      # Pattern-specific scoring
      case "$pattern" in
        *"【"*"】"*) score=$((score + 50)) ;;  # Japanese brackets are strong indicators
        *"["*"]"*) score=$((score + 30)) ;;   # Square brackets are good indicators
        *"("*")"*) score=$((score + 20)) ;;   # Parentheses are moderate indicators
        *"-"*) score=$((score + 10)) ;;       # Dash is common but less reliable
        *"|"*|*"｜"*) score=$((score + 25)) ;; # Pipes are good separators
      esac
      
      # Length balance scoring (prefer balanced lengths)
      local len_artist=${#artist_candidate}
      local len_title=${#title_candidate}
      local total_len=$((len_artist + len_title))
      local ratio=$((len_artist * 100 / total_len))
      
      if [[ $ratio -ge 20 && $ratio -le 80 ]]; then
        score=$((score + 20))  # Good balance
      elif [[ $ratio -ge 10 && $ratio -le 90 ]]; then
        score=$((score + 10))  # Acceptable balance
      fi
      
      # Avoid obvious non-artist patterns
      if [[ "$artist_candidate" =~ ^[0-9]+$ ]] || [[ "$artist_candidate" =~ ^[0-9]+-[0-9]+$ ]]; then
        score=$((score - 30))  # Numbers are unlikely to be artists
      fi
      
      # Prefer patterns where artist looks like artist (shorter, cleaner)
      if [[ ${#artist_candidate} -le 20 && ! "$artist_candidate" =~ [/\\] ]]; then
        score=$((score + 15))
      fi
      
      # Boost if artist contains common artist indicators
      if [[ "$artist_candidate" =~ (feat\.|ft\.|vs\.|&) ]]; then
        score=$((score + 10))
      fi
      
      # Penalty for obvious title-like content in artist field
      if [[ "$artist_candidate" =~ (MV|Official|Video|Lyrics|HD|4K) ]]; then
        score=$((score - 20))
      fi
      
      # Update best match if score is higher
      if [[ $score -gt $best_score ]]; then
        best_score=$score
        best_artist="$artist_candidate"
        best_title="$title_candidate"
      fi
    fi
  done
  
  # If we found a good match (score > threshold), use it
  if [[ $best_score -gt 15 ]]; then
    echo "$best_artist|$best_title"
  else
    echo "|$input"  # Return as title only
  fi
}

# Find which media is "Playing"
active_media=$(playerctl -l 2>/dev/null | while read -r player; do
  status=$(playerctl -p "$player" status 2>/dev/null)
  if [ "$status" = "Playing" ]; then
    echo "$player"
    break
  fi
done)

# If there is no media playing, display "No media"
if [ -z "$active_media" ]; then
  echo '{"text": "  No media", "tooltip": ""}'
  exit 0
fi

# Get metadata from the current playing media
title=$(playerctl -p "$active_media" metadata title 2>/dev/null)
artist=$(playerctl -p "$active_media" metadata artist 2>/dev/null)

# If there is no title, escape early
if [ -z "$title" ]; then
  echo '{"text": "  No media", "tooltip": ""}'
  exit 0
fi

# Advanced title cleaning
original_title="$title"

# Remove file extensions
title=$(echo "$title" | sed -E 's/\.(mp4|mp3|flac|wav|m4a|ogg|webm)$//i')

# Remove YouTube/video IDs - multiple patterns
title=$(echo "$title" | sed -E 's/\s*\[[a-zA-Z0-9_-]{8,}\]$//') # [kagoEGKHZvU]
title=$(echo "$title" | sed -E 's/\s*\[[a-zA-Z0-9_-]{8,}\]\.(mp4|mp3|webm)$//i') # [ID].ext if still there

# Remove common video suffixes
title=$(echo "$title" | sed -E 's/\s*\(Official Music Video\)$//i')
title=$(echo "$title" | sed -E 's/\s*\(Official Video\)$//i')
title=$(echo "$title" | sed -E 's/\s*\(Music Video\)$//i')
title=$(echo "$title" | sed -E 's/\s*\(Official MV\)$//i')
title=$(echo "$title" | sed -E 's/\s*\(MV\)$//i')
title=$(echo "$title" | sed -E 's/\s*\(Official\)$//i')
title=$(echo "$title" | sed -E 's/\s*\[YouTube ver\.\]$//i')
title=$(echo "$title" | sed -E 's/\s*\[.*ver\.\]$//i')
title=$(echo "$title" | sed -E 's/\s*-\s*Official.*$//i')

# Remove quality indicators
title=$(echo "$title" | sed -E 's/\s*\(4K.*\)$//i')
title=$(echo "$title" | sed -E 's/\s*\(HD.*\)$//i')
title=$(echo "$title" | sed -E 's/\s*4K\s*$//i')

# Remove extended/remix indicators at the end that might confuse parsing
title=$(echo "$title" | sed -E 's/\s*\([0-9]+mn extended\)$//i')

# Clean up extra whitespace
title=$(echo "$title" | sed -E 's/\s+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')

# If we don't have artist from metadata, try to extract from title
if [ -z "$artist" ]; then
  extraction_result=$(extract_artist_title "$title")
  extracted_artist="${extraction_result%|*}"
  extracted_title="${extraction_result#*|}"
  
  if [ -n "$extracted_artist" ]; then
    artist="$extracted_artist"
    title="$extracted_title"
  fi
else
  # We have metadata artist, but let's see if title contains better info
  extraction_result=$(extract_artist_title "$title")
  extracted_artist="${extraction_result%|*}"
  extracted_title="${extraction_result#*|}"
  
  # Compare with existing artist
  norm_extracted=$(normalize "$extracted_artist")
  norm_existing=$(normalize "$artist")
  
  # If extracted artist matches or is more specific, use extraction
  if [ -n "$extracted_artist" ] && [[ "$norm_extracted" == "$norm_existing"* || "$norm_existing" == "$norm_extracted"* ]]; then
    artist="$extracted_artist"
    title="$extracted_title"
  fi
fi

# Final cleanup
title=$(echo "$title" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
artist=$(echo "$artist" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

# Create a display text
if [ -n "$artist" ] && [ -n "$title" ]; then
  short_title=$(truncate_text "$title" 15)
  short_artist=$(truncate_text "$artist" 10)
  display_text="  $short_title | $short_artist"
else
  short_title=$(truncate_text "$title" 25)
  display_text="  $short_title"
fi

# Create tooltip content
tooltip_content=""
if [ -n "$artist" ] && [ -n "$title" ]; then
  tooltip_content="$title — $artist"
elif [ -n "$title" ]; then
  tooltip_content="$title"
else
  tooltip_content="$original_title"
fi

# Escape and export with error handling
escaped_display=$(html_escape "$display_text")

# First HTML escape the tooltip content, then JSON escape it
html_escaped_tooltip=$(html_escape "$tooltip_content")
escaped_tooltip=$(json_escape "$html_escaped_tooltip" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$escaped_tooltip" ] || [ "$escaped_tooltip" = "null" ]; then
  # Fallback: clean problematic characters and try again
  clean_tooltip=$(echo "$tooltip_content" | sed 's/["\]//g' | tr -d '\000-\037')
  escaped_tooltip=$(json_escape "$clean_tooltip" 2>/dev/null)
  
  # If still fails, use basic escaping
  if [ $? -ne 0 ] || [ -z "$escaped_tooltip" ] || [ "$escaped_tooltip" = "null" ]; then
    escaped_tooltip="\"$(echo "$clean_tooltip" | sed 's/"/\\"/g')\""
  fi
fi

# Ensure tooltip is not empty
if [ -z "$escaped_tooltip" ] || [ "$escaped_tooltip" = "null" ] || [ "$escaped_tooltip" = '""' ]; then
  escaped_tooltip="\"Now Playing\""
fi

echo "{\"text\": \"$escaped_display\", \"tooltip\": $escaped_tooltip}"