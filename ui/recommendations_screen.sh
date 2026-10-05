#!/usr/bin/env bash

# Recommendation UI: progress, shortlist cards, and an optional save choice.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=theme.sh
. "$ROOT_DIR/ui/theme.sh"

case "${1:-}" in
  heading)
    ui_heading "Recommendation Lab"
    printf 'Three independent readers are exploring your shelf in parallel.\n\n'
    ;;
  progress)
    state="${2:-running}"
    label="${3:-Recommendation agent}"
    if [ "$state" = "done" ]; then
      if has_gum; then gum style --foreground 42 "✓ $label"; else printf '[done] %s\n' "$label"; fi
    else
      if has_gum; then gum style --foreground 214 "◌ $label"; else printf '[running] %s\n' "$label"; fi
    fi
    ;;
  timer)
    elapsed="${2:-0}"
    if [ -t 1 ]; then printf '\r  composing signals... %ss' "$elapsed"; fi
    ;;
  timer-done)
    if [ -t 1 ]; then printf '\r%*s\r' 48 ''; fi
    ;;
  show)
    file="${2:?recommendation file required}"
    number=1
    while IFS='|' read -r score title author genre year pages pace strategy reason link; do
      printf '\n%d. %s - %s\n' "$number" "$title" "$author"
      printf '   %s · %s pages · %s pace · %s signal · score %s\n' \
        "$genre" "${pages:-?}" "$pace" "$strategy" "$score"
      printf '   %s\n' "$reason"
      number=$((number + 1))
    done < "$file"
    ;;
  choose)
    file="${2:?recommendation file required}"
    candidates=()
    options=("Not now - keep the shortlist")
    while IFS= read -r candidate; do
      candidates+=("$candidate")
      IFS='|' read -r score title author genre year pages pace strategy reason link <<EOF
$candidate
EOF
      options+=("$title - $author [$strategy]")
    done < "$file"
    selected="$(ui_choose "Queue one as your next read?" "${options[@]}")" || exit 0
    [ "$selected" != "${options[0]}" ] || exit 0
    index=1
    for option in "${options[@]:1}"; do
      if [ "$option" = "$selected" ]; then
        printf '%s\n' "${candidates[$((index - 1))]}"
        exit 0
      fi
      index=$((index + 1))
    done
    ;;
  *)
    echo "Usage: $0 {heading|progress STATE LABEL|timer SECONDS|timer-done|show FILE|choose FILE}" >&2
    exit 2
    ;;
esac
