#!/usr/bin/env bash

# Match catalog topics against the reader's editable interests and constraints.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="${BOOK_MANAGER_PROFILE:-$ROOT_DIR/data/reader_profile.txt}"
delay="${BOOK_MANAGER_AGENT_DELAY:-0.8}"
sleep "$delay"

interests="$(awk -F= '$1 == "interests" { sub(/^[^=]*=/, ""); print; exit }' "$PROFILE")"
preferred_pace="$(awk -F= '$1 == "preferred_pace" { print $2; exit }' "$PROFILE")"
max_pages="$(awk -F= '$1 == "max_pages" { print $2; exit }' "$PROFILE")"

awk -F'|' -v interests="$interests" -v preferred_pace="$preferred_pace" -v max_pages="$max_pages" '
  BEGIN {
    count=split(tolower(interests), raw, ",")
    for (i=1; i<=count; i++) {
      gsub(/^ +| +$/, "", raw[i])
      if (raw[i] != "") wanted[++wanted_count]=raw[i]
    }
  }
  $0 !~ /^#/ {
    topics=tolower($6)
    matches=0
    matched=""
    for (i=1; i<=wanted_count; i++) {
      if (index(topics, wanted[i]) > 0) {
        matches++
        matched=(matched == "" ? wanted[i] : matched ", " wanted[i])
      }
    }
    if (matches > 0) {
      score=74 + matches*6
      if (tolower($7) == tolower(preferred_pace)) score+=3
      if (($5+0) <= (max_pages+0)) score+=2
      if (score > 98) score=98
      printf "%d|%s|%s|%s|%s|%s|%s|interests|Matches your lens: %s|%s\n", \
        score,$1,$2,$3,$4,$5,$7,matched,$9
    }
  }
' "$ROOT_DIR/data/book_catalog.txt" | sort -t'|' -k1,1nr | head -n 12
