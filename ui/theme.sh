#!/usr/bin/env bash

# Shared presentation primitives for the Gum interface and portable fallback.

has_gum() {
  command -v gum >/dev/null 2>&1
}

ui_brand() {
  if has_gum; then
    gum style --foreground 45 --border-foreground 45 --bold --border double \
      --align center --width 68 --padding "1 2" \
      "CURIOUS SHELF" \
      "Systems, stories, and better questions."
  else
    printf '\n+------------------------------------------------------------------+\n'
    printf '|                          CURIOUS SHELF                           |\n'
    printf '|               Systems, stories, and better questions.          |\n'
    printf '+------------------------------------------------------------------+\n'
  fi
}

ui_heading() {
  if has_gum; then
    gum style --foreground 45 --bold --border rounded --padding "0 2" "$1"
  else
    printf '\n=== %s ===\n' "$1"
  fi
}

ui_message() {
  if has_gum; then gum style --foreground 42 "✓ $1"; else printf '✓ %s\n' "$1"; fi
}

ui_error() {
  if has_gum; then gum style --foreground 196 "! $1" >&2; else printf '! %s\n' "$1" >&2; fi
}

ui_prompt() {
  local label="$1" placeholder="${2:-}" value
  if has_gum; then
    gum input --prompt "$label: " --placeholder "$placeholder"
  else
    printf '%s: ' "$label" > /dev/tty
    IFS= read -r value < /dev/tty
    printf '%s\n' "$value"
  fi
}

ui_choose() {
  local header="$1" index option selection
  shift
  if has_gum; then
    gum choose --cursor.foreground 45 --selected.foreground 45 --header "$header" "$@"
    return
  fi

  printf '%s\n' "$header" > /dev/tty
  index=1
  for option in "$@"; do
    printf '  %d) %s\n' "$index" "$option" > /dev/tty
    index=$((index + 1))
  done
  printf '> ' > /dev/tty
  IFS= read -r selection < /dev/tty
  [ "$selection" -ge 1 ] 2>/dev/null && [ "$selection" -lt "$index" ] || return 1
  index=1
  for option in "$@"; do
    if [ "$selection" -eq "$index" ]; then
      printf '%s\n' "$option"
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

ui_pause() {
  if has_gum; then
    gum input --prompt "Press Enter to return " --placeholder " " >/dev/null
  else
    printf '\nPress Enter to return...' > /dev/tty
    IFS= read -r unused < /dev/tty
  fi
}
