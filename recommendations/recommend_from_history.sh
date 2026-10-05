#!/usr/bin/env bash

# Follow genres that the reader has finished, rated highly, or kept active.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
delay="${BOOK_MANAGER_AGENT_DELAY:-0.8}"
sleep "$delay"

"$ROOT_DIR/data/book_database.sh" list | awk -F'|' -v catalog="$ROOT_DIR/data/book_catalog.txt" '
  {
    weight=1
    if ($7 == "reading") weight+=2
    if ($7 == "finished") weight+=3
    if ($8+0 >= 4) weight+=($8+0)-2
    genre_weight[tolower($4)]+=weight
  }
  END {
    while ((getline line < catalog) > 0) {
      if (line ~ /^#/) continue
      split(line, b, "|")
      genre=tolower(b[3])
      if (genre_weight[genre] > 0) {
        score=int(70 + genre_weight[genre])
        if (score > 94) score=94
        printf "%d|%s|%s|%s|%s|%s|%s|history|Your shelf gives %s a strong signal|%s\n", \
          score,b[1],b[2],b[3],b[4],b[5],b[7],b[3],b[9]
      }
    }
    close(catalog)
  }
' | sort -t'|' -k1,1nr | head -n 8
