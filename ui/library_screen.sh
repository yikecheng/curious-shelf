#!/usr/bin/env bash

# Library UI: collect input and render records supplied by a workflow.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=theme.sh
. "$ROOT_DIR/ui/theme.sh"

show_records() {
  local records rating pages
  records="$(cat)"
  if [ -z "$records" ]; then
    printf 'No books match yet.\n'
    return 0
  fi

  printf '%-3s  %-30s  %-21s  %-18s  %-12s  %s\n' \
    "ID" "TITLE" "AUTHOR" "GENRE" "STATUS" "RATING"
  printf '%s\n' "$records" | while IFS='|' read -r id title author genre year pages status rating pace link added; do
    [ -n "$rating" ] || rating="-"
    [ -n "$pages" ] || pages="?"
    printf '%-3s  %-30.30s  %-21.21s  %-18.18s  %-12s  %s\n' \
      "$id" "$title" "$author" "$genre" "$status" "$rating"
  done
}

show_stats() {
  local total want reading finished owned average profile
  while IFS='|' read -r key value; do
    case "$key" in
      total) total="$value" ;;
      want-to-read) want="$value" ;;
      reading) reading="$value" ;;
      finished) finished="$value" ;;
      owned) owned="$value" ;;
      average-rating) average="$value" ;;
    esac
  done
  profile="${1:-}"
  printf '  %s books  ·  %s reading  ·  %s finished  ·  %s queued  ·  %s owned  ·  avg rating %s\n' \
    "${total:-0}" "${reading:-0}" "${finished:-0}" "${want:-0}" "${owned:-0}" "${average:--}"
  [ -z "$profile" ] || printf '  Reading lens: %s\n' "$profile"
}

select_book() {
  local records selected index option
  records="$(cat)"
  [ -n "$records" ] || return 1
  options=()
  titles=()
  while IFS='|' read -r id title author genre year pages status rating pace link added; do
    options+=("$title - $author [$status]")
    titles+=("$title")
  done <<EOF
$records
EOF
  selected="$(ui_choose "Choose a book" "${options[@]}")" || return 1
  index=0
  for option in "${options[@]}"; do
    if [ "$option" = "$selected" ]; then
      printf '%s\n' "${titles[$index]}"
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

case "${1:-}" in
  heading)
    ui_heading "${2:-Your Library}"
    ;;
  show)
    show_records
    ;;
  stats)
    show_stats "${2:-}"
    ;;
  collect-add)
    ui_heading "Add a Book" >&2
    title="$(ui_prompt "Title" "e.g. The Alignment Problem")"
    [ -n "$title" ] || exit 1
    author="$(ui_prompt "Author" "optional for cataloged books")"
    status="$(ui_choose "Reading status" "want-to-read" "reading" "finished" "owned")" || exit 1
    rating=""
    if [ "$status" = "finished" ]; then
      rating="$(ui_choose "Rating" "5" "4.5" "4" "3.5" "3" "2.5" "2" "1" "0")" || exit 1
    fi
    printf '%s|%s|%s|%s\n' "$title" "$author" "$status" "$rating"
    ;;
  prompt-search)
    ui_prompt "Search title, author, genre, pace, or status" "design"
    ;;
  select-book)
    select_book
    ;;
  choose-status)
    ui_choose "New reading status" "want-to-read" "reading" "finished" "owned"
    ;;
  choose-rating)
    ui_choose "Rating" "5" "4.5" "4" "3.5" "3" "2.5" "2" "1" "0"
    ;;
  collect-profile)
    ui_heading "Tune Your Reading Lens" >&2
    interests="$(ui_prompt "Interests (comma-separated)" "AI, design, cities, writing")"
    pace="$(ui_choose "Preferred reading pace" "thoughtful" "brisk" "gentle" "immersive" "curious" "deep")" || exit 1
    max_pages="$(ui_prompt "Comfortable maximum pages" "400")"
    printf '%s|%s|%s\n' "$interests" "$pace" "$max_pages"
    ;;
  message)
    ui_message "${2:-Done.}"
    ;;
  error)
    ui_error "${2:-Something went wrong.}"
    ;;
  *)
    echo "Usage: $0 {heading|show|stats|collect-add|prompt-search|select-book|choose-status|choose-rating|collect-profile|message|error}" >&2
    exit 2
    ;;
esac
