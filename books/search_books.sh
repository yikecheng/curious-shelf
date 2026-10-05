#!/usr/bin/env bash

# Search component. Storage access remains behind the database abstraction.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$#" -ge 1 ]; then
  term="$1"
else
  IFS= read -r term
fi

[ -n "${term:-}" ] || { echo "A search term is required." >&2; exit 1; }
"$ROOT_DIR/data/book_database.sh" search "$term"
