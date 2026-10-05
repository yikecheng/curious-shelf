#!/usr/bin/env bash

# Enrich title/author input from a small, inspectable offline catalog.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT_DIR/data/book_catalog.txt"

if [ "$#" -ge 1 ]; then
  title="$1"
  author="${2:-}"
else
  IFS='|' read -r title author
fi

[ -n "${title:-}" ] || { echo "A title is required." >&2; exit 1; }

match="$(awk -F'|' -v title="$title" -v author="${author:-}" '
  $0 !~ /^#/ && tolower($1) == tolower(title) && (author == "" || index(tolower($2), tolower(author)) > 0) {
    print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $7 "|" $9
    exit
  }
' "$CATALOG")"

if [ -n "$match" ]; then
  printf '%s\n' "$match"
else
  printf '%s|%s|Uncategorized|||thoughtful|\n' "$title" "${author:-Unknown author}"
fi
