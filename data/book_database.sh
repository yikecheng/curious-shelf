#!/usr/bin/env bash

# Data abstraction. This is the only application component that touches books.csv.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB_FILE="${BOOK_MANAGER_DB:-$ROOT_DIR/data/books.csv}"
HEADER="id,title,author,genre,year,pages,status,rating,pace,link,date_added"

usage() {
  echo "Usage: $0 {init|list|search|status|add|exists|update-status|update-rating|stats}" >&2
  exit 2
}

clean_field() {
  printf '%s' "$1" | tr '\n\r,|' '    ' | sed 's/^ *//; s/ *$//; s/  */ /g'
}

valid_status() {
  case "$1" in
    owned|want-to-read|reading|finished) return 0 ;;
    *) return 1 ;;
  esac
}

valid_rating() {
  [ -z "$1" ] || awk -v value="$1" 'BEGIN { exit !(value ~ /^([0-4]([.][05])?|5([.]0)?)$/) }'
}

init_db() {
  mkdir -p "$(dirname "$DB_FILE")"
  if [ ! -f "$DB_FILE" ]; then
    printf '%s\n' "$HEADER" > "$DB_FILE"
  fi
}

emit_rows() {
  awk -F',' 'NR > 1 { OFS="|"; print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11 }' "$DB_FILE"
}

find_id() {
  local title
  title="$(clean_field "$1")"
  awk -F',' -v title="$title" 'NR > 1 && tolower($2) == tolower(title) { print $1; exit }' "$DB_FILE"
}

init_db
command="${1:-}"

case "$command" in
  init)
    ;;
  list)
    emit_rows
    ;;
  search)
    term="$(clean_field "${2:-}")"
    [ -n "$term" ] || { echo "Search term is required." >&2; exit 1; }
    emit_rows | awk -F'|' -v term="$term" 'index(tolower($0), tolower(term)) > 0'
    ;;
  status)
    status="$(clean_field "${2:-}")"
    valid_status "$status" || { echo "Invalid status: $status" >&2; exit 1; }
    emit_rows | awk -F'|' -v status="$status" '$7 == status'
    ;;
  exists)
    title="$(clean_field "${2:-}")"
    author="$(clean_field "${3:-}")"
    awk -F',' -v title="$title" -v author="$author" '
      NR > 1 && tolower($2) == tolower(title) && (author == "" || tolower($3) == tolower(author)) { found=1 }
      END { exit !found }
    ' "$DB_FILE"
    ;;
  add)
    [ "$#" -eq 10 ] || usage
    title="$(clean_field "$2")"
    author="$(clean_field "$3")"
    genre="$(clean_field "$4")"
    year="$(clean_field "$5")"
    pages="$(clean_field "$6")"
    status="$(clean_field "$7")"
    rating="$(clean_field "$8")"
    pace="$(clean_field "$9")"
    link="$(clean_field "${10}")"

    [ -n "$title" ] && [ -n "$author" ] || { echo "Title and author are required." >&2; exit 1; }
    valid_status "$status" || { echo "Invalid status: $status" >&2; exit 1; }
    valid_rating "$rating" || { echo "Rating must be blank or 0-5 in half-point steps." >&2; exit 1; }
    if [ -n "$year" ]; then
      [ "$year" -ge 1400 ] 2>/dev/null && [ "$year" -le 2200 ] || { echo "Invalid year: $year" >&2; exit 1; }
    fi
    if [ -n "$pages" ]; then
      [ "$pages" -ge 1 ] 2>/dev/null && [ "$pages" -le 10000 ] || { echo "Invalid page count: $pages" >&2; exit 1; }
    fi
    if "$0" exists "$title" "$author"; then
      echo "That book is already in the library." >&2
      exit 1
    fi

    next_id="$(awk -F',' 'NR > 1 && $1+0 > max { max=$1+0 } END { print max+1 }' "$DB_FILE")"
    added="$(date +%Y-%m-%d)"
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
      "$next_id" "$title" "$author" "$genre" "$year" "$pages" "$status" "$rating" "$pace" "$link" "$added" >> "$DB_FILE"
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$next_id" "$title" "$author" "$genre" "$year" "$pages" "$status" "$rating" "$pace" "$link" "$added"
    ;;
  update-status)
    id="$(find_id "${2:-}")"
    status="$(clean_field "${3:-}")"
    [ -n "$id" ] || { echo "Book not found: ${2:-}" >&2; exit 1; }
    valid_status "$status" || { echo "Invalid status: $status" >&2; exit 1; }
    tmp_file="$(mktemp "${TMPDIR:-/tmp}/curious-db.XXXXXX")"
    awk -F',' -v OFS=',' -v id="$id" -v value="$status" '{ if ($1 == id) $7=value; print }' "$DB_FILE" > "$tmp_file"
    mv "$tmp_file" "$DB_FILE"
    ;;
  update-rating)
    id="$(find_id "${2:-}")"
    rating="$(clean_field "${3:-}")"
    [ -n "$id" ] || { echo "Book not found: ${2:-}" >&2; exit 1; }
    valid_rating "$rating" || { echo "Rating must be blank or 0-5 in half-point steps." >&2; exit 1; }
    tmp_file="$(mktemp "${TMPDIR:-/tmp}/curious-db.XXXXXX")"
    awk -F',' -v OFS=',' -v id="$id" -v value="$rating" '{ if ($1 == id) $8=value; print }' "$DB_FILE" > "$tmp_file"
    mv "$tmp_file" "$DB_FILE"
    ;;
  stats)
    emit_rows | awk -F'|' '
      {
        total++
        status[$7]++
        if ($8 != "") { rating_total+=$8; rating_count++ }
      }
      END {
        printf "total|%d\n", total
        printf "want-to-read|%d\n", status["want-to-read"]
        printf "reading|%d\n", status["reading"]
        printf "finished|%d\n", status["finished"]
        printf "owned|%d\n", status["owned"]
        if (rating_count) printf "average-rating|%.1f\n", rating_total/rating_count
        else print "average-rating|-"
      }
    '
    ;;
  *) usage ;;
esac
