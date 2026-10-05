#!/usr/bin/env bash

# Seek deliberate detours in genres not yet represented on the shelf.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
delay="${BOOK_MANAGER_AGENT_DELAY:-0.8}"
sleep "$delay"

"$ROOT_DIR/data/book_database.sh" list | awk -F'|' -v catalog="$ROOT_DIR/data/book_catalog.txt" '
  { familiar[tolower($4)]=1 }
  END {
    rank=0
    while ((getline line < catalog) > 0) {
      if (line ~ /^#/) continue
      split(line, b, "|")
      genre=tolower(b[3])
      signals=tolower(b[8])
      if (index(signals, "wildcard") > 0 && !familiar[genre]) {
        score=79-rank
        printf "%d|%s|%s|%s|%s|%s|%s|discovery|A purposeful detour into %s to widen your shelf|%s\n", \
          score,b[1],b[2],b[3],b[4],b[5],b[7],b[3],b[9]
        rank++
        if (rank == 7) break
      }
    }
    close(catalog)
  }
'
