#!/usr/bin/env bash

# Rank candidates from stdin, then deduplicate, exclude saved books, and diversify.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="${BOOK_MANAGER_PROFILE:-$ROOT_DIR/data/reader_profile.txt}"
raw="$(mktemp "${TMPDIR:-/tmp}/curious-candidates.XXXXXX")"
scored="$(mktemp "${TMPDIR:-/tmp}/curious-scored.XXXXXX")"
existing="$(mktemp "${TMPDIR:-/tmp}/curious-existing.XXXXXX")"
trap 'rm -f "$raw" "$scored" "$existing"' EXIT INT TERM

cat > "$raw"
"$ROOT_DIR/data/book_database.sh" list > "$existing"

preferred_pace="$(awk -F= '$1 == "preferred_pace" { print $2; exit }' "$PROFILE")"
max_pages="$(awk -F= '$1 == "max_pages" { print $2; exit }' "$PROFILE")"

# Refinement adds a small, visible fit bonus without overpowering agent signals.
awk -F'|' -v OFS='|' -v preferred_pace="$preferred_pace" -v max_pages="$max_pages" '
  NF >= 10 {
    bonus=0
    fit=""
    if (tolower($7) == tolower(preferred_pace)) { bonus+=2; fit="preferred pace" }
    if (($6+0) <= (max_pages+0)) {
      bonus+=1
      fit=(fit == "" ? "within page budget" : fit " + page budget")
    }
    $1=($1+0)+bonus
    if (fit != "") $9=$9 "; " fit
    print
  }
' "$raw" | sort -t'|' -k1,1nr > "$scored"

# First file builds an exclusion set through the data layer. The second is ranked.
awk -F'|' '
  BEGIN { OFS="|" }
  NR == FNR {
    existing[tolower($2 "|" $3)]=1
    next
  }
  {
    key=tolower($2 "|" $3)
    genre=tolower($4)
    if (!existing[key] && !seen[key] && genre_count[genre] < 2 && total < 6) {
      print
      seen[key]=1
      genre_count[genre]++
      total++
    }
  }
' "$existing" "$scored"
