#!/usr/bin/env bash

# Coordinate UI, book components, profile settings, and the database layer.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB="$ROOT_DIR/data/book_database.sh"
UI="$ROOT_DIR/ui/library_screen.sh"
PROFILE="$ROOT_DIR/data/reader_profile.txt"

profile_summary() {
  local interests pace max_pages
  interests="$(awk -F= '$1 == "interests" { sub(/^[^=]*=/, ""); print; exit }' "$PROFILE")"
  pace="$(awk -F= '$1 == "preferred_pace" { print $2; exit }' "$PROFILE")"
  max_pages="$(awk -F= '$1 == "max_pages" { print $2; exit }' "$PROFILE")"
  printf '%s · %s pace · up to %s pages\n' "$interests" "$pace" "$max_pages"
}

show_dashboard() {
  "$UI" heading "Reading Dashboard"
  "$DB" stats | "$UI" stats "$(profile_summary)"
  printf '\n'
  "$DB" list | "$UI" show
}

add_book() {
  local input requested_title requested_author status rating metadata
  local title author genre year pages pace link
  input="${1:-}"
  if [ -z "$input" ]; then
    input="$("$UI" collect-add)" || return 0
  fi
  IFS='|' read -r requested_title requested_author status rating <<EOF
$input
EOF

  metadata="$(printf '%s|%s\n' "$requested_title" "$requested_author" | "$ROOT_DIR/books/fetch_book_metadata.sh")"
  IFS='|' read -r title author genre year pages pace link <<EOF
$metadata
EOF

  if "$DB" add "$title" "$author" "$genre" "$year" "$pages" "$status" "$rating" "$pace" "$link" >/dev/null; then
    "$UI" message "Added $title to your $status shelf."
  else
    "$UI" error "Could not add $title. It may already be saved or contain invalid data."
    return 1
  fi
}

search_library() {
  local term
  term="${1:-}"
  [ -n "$term" ] || term="$("$UI" prompt-search)"
  [ -n "$term" ] || return 0
  "$UI" heading "Search Results"
  printf '%s\n' "$term" | "$ROOT_DIR/books/search_books.sh" | "$UI" show
}

select_saved_title() {
  "$DB" list | "$UI" select-book
}

update_status() {
  local title status
  title="${1:-}"
  status="${2:-}"
  [ -n "$title" ] || title="$(select_saved_title)" || return 0
  [ -n "$status" ] || status="$("$UI" choose-status)" || return 0
  "$DB" update-status "$title" "$status"
  "$UI" message "Moved $title to $status."
}

update_rating() {
  local title rating
  title="${1:-}"
  rating="${2:-}"
  [ -n "$title" ] || title="$(select_saved_title)" || return 0
  [ -n "$rating" ] || rating="$("$UI" choose-rating)" || return 0
  "$DB" update-rating "$title" "$rating"
  "$UI" message "Rated $title $rating out of 5."
}

tune_profile() {
  local input interests pace max_pages
  input="${1:-}"
  [ -n "$input" ] || input="$("$UI" collect-profile)" || return 0
  IFS='|' read -r interests pace max_pages <<EOF
$input
EOF
  interests="$(printf '%s' "$interests" | tr '\n\r|=' '    ' | sed 's/^ *//; s/ *$//; s/  */ /g')"
  pace="$(printf '%s' "$pace" | tr '\n\r|=' '    ' | sed 's/^ *//; s/ *$//')"
  max_pages="$(printf '%s' "$max_pages" | tr -cd '0-9')"
  [ -n "$interests" ] && [ -n "$pace" ] || { "$UI" error "Interests and pace are required."; return 1; }
  [ -n "$max_pages" ] && [ "$max_pages" -ge 80 ] 2>/dev/null && [ "$max_pages" -le 1500 ] || {
    "$UI" error "Maximum pages must be between 80 and 1500."
    return 1
  }
  printf 'interests=%s\npreferred_pace=%s\nmax_pages=%s\n' \
    "$interests" "$pace" "$max_pages" > "$PROFILE"
  "$UI" message "Your reading lens now favors $interests."
}

save_recommendation() {
  local title author genre year pages pace link
  title="$1"; author="$2"; genre="$3"; year="$4"; pages="$5"; pace="$6"; link="$7"
  "$DB" add "$title" "$author" "$genre" "$year" "$pages" "want-to-read" "" "$pace" "$link" >/dev/null
  "$UI" message "Queued $title as a future read."
}

case "${1:-}" in
  dashboard|list) show_dashboard ;;
  add) add_book "${2:-}" ;;
  search) search_library "${2:-}" ;;
  update-status) update_status "${2:-}" "${3:-}" ;;
  rate) update_rating "${2:-}" "${3:-}" ;;
  profile) tune_profile "${2:-}" ;;
  add-recommendation)
    [ "$#" -eq 8 ] || { echo "Incomplete recommendation." >&2; exit 2; }
    save_recommendation "$2" "$3" "$4" "$5" "$6" "$7" "$8"
    ;;
  *)
    echo "Usage: $0 {dashboard|add|search|update-status|rate|profile|add-recommendation}" >&2
    exit 2
    ;;
esac
