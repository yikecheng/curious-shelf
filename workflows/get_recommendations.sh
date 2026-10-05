#!/usr/bin/env bash

# Run three independent agents concurrently, synchronize, compose, and display.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UI="$ROOT_DIR/ui/recommendations_screen.sh"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/curious-shelf-recs.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT INT TERM

"$UI" heading

"$ROOT_DIR/recommendations/recommend_from_history.sh" > "$work_dir/history.txt" &
history_pid=$!
"$UI" progress running "History reader is tracing your strongest shelf signals"

"$ROOT_DIR/recommendations/recommend_from_interests.sh" > "$work_dir/interests.txt" &
interests_pid=$!
"$UI" progress running "Interest reader is matching your editable reading lens"

"$ROOT_DIR/recommendations/recommend_for_discovery.sh" > "$work_dir/discovery.txt" &
discovery_pid=$!
"$UI" progress running "Discovery reader is looking beyond familiar genres"

started="$(date +%s)"
while kill -0 "$history_pid" 2>/dev/null || kill -0 "$interests_pid" 2>/dev/null || kill -0 "$discovery_pid" 2>/dev/null; do
  "$UI" timer "$(( $(date +%s) - started ))"
  sleep 0.2
done
"$UI" timer-done

wait "$history_pid"
history_status=$?
wait "$interests_pid"
interests_status=$?
wait "$discovery_pid"
discovery_status=$?

[ "$history_status" -eq 0 ] || { echo "History reader failed." >&2; exit 1; }
[ "$interests_status" -eq 0 ] || { echo "Interest reader failed." >&2; exit 1; }
[ "$discovery_status" -eq 0 ] || { echo "Discovery reader failed." >&2; exit 1; }

"$UI" progress done "History reader finished"
"$UI" progress done "Interest reader finished"
"$UI" progress done "Discovery reader finished"

# Required composition pipeline: combine candidates -> refine -> final shortlist.
cat "$work_dir/history.txt" "$work_dir/interests.txt" "$work_dir/discovery.txt" \
  | "$ROOT_DIR/recommendations/refine_recommendations.sh" \
  > "$work_dir/final.txt"

if [ ! -s "$work_dir/final.txt" ]; then
  printf 'No unseen recommendations fit the current lens. Try widening your profile.\n'
  exit 0
fi

"$UI" show "$work_dir/final.txt"

if [ "${1:-}" != "--non-interactive" ] && [ -t 0 ]; then
  selected="$("$UI" choose "$work_dir/final.txt")"
  if [ -n "$selected" ]; then
    IFS='|' read -r score title author genre year pages pace strategy reason link <<EOF
$selected
EOF
    "$ROOT_DIR/workflows/manage_library.sh" add-recommendation \
      "$title" "$author" "$genre" "$year" "$pages" "$pace" "$link"
  fi
fi
