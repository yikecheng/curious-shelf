#!/usr/bin/env bash

# Main UI loop. It gathers intent, then delegates complete actions to workflows.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=theme.sh
. "$ROOT_DIR/ui/theme.sh"

LIBRARY="$ROOT_DIR/workflows/manage_library.sh"
RECOMMEND="$ROOT_DIR/workflows/get_recommendations.sh"

OPTIONS=(
  "Reading Dashboard"
  "Add a Book"
  "Search the Shelf"
  "Update Reading Status"
  "Rate a Finished Book"
  "Open Recommendation Lab"
  "Tune Reading Lens"
  "Quit"
)

ui_brand
if ! has_gum; then
  printf 'Tip: install Gum for the full interactive interface.\n'
fi

while :; do
  action="$(ui_choose "Where should curiosity go next?" "${OPTIONS[@]}")" || break
  case "$action" in
    "Reading Dashboard") "$LIBRARY" dashboard ;;
    "Add a Book") "$LIBRARY" add ;;
    "Search the Shelf") "$LIBRARY" search ;;
    "Update Reading Status") "$LIBRARY" update-status ;;
    "Rate a Finished Book") "$LIBRARY" rate ;;
    "Open Recommendation Lab") "$RECOMMEND" ;;
    "Tune Reading Lens") "$LIBRARY" profile ;;
    "Quit") break ;;
  esac
  ui_pause
done

printf '\nKeep following the interesting questions.\n'
