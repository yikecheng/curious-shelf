#!/usr/bin/env bash

# Isolated component, boundary, and end-to-end checks.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/curious-shelf-tests.XXXXXX")"
export BOOK_MANAGER_DB="$TEST_DIR/books.csv"
export BOOK_MANAGER_PROFILE="$TEST_DIR/reader_profile.txt"
export BOOK_MANAGER_AGENT_DELAY=0
trap 'rm -rf "$TEST_DIR"' EXIT INT TERM

cp "$ROOT_DIR/data/reader_profile.txt" "$BOOK_MANAGER_PROFILE"

passed=0
failed=0

pass() {
  passed=$((passed + 1))
  printf '✓ %s\n' "$1"
}

fail() {
  failed=$((failed + 1))
  printf '✗ %s\n' "$1" >&2
}

assert_contains() {
  local name="$1" text="$2" expected="$3"
  if printf '%s\n' "$text" | grep -Fq "$expected"; then pass "$name"; else fail "$name"; fi
}

assert_not_contains() {
  local name="$1" text="$2" unwanted="$3"
  if printf '%s\n' "$text" | grep -Fq "$unwanted"; then fail "$name"; else pass "$name"; fi
}

for script in \
  "$ROOT_DIR/app.sh" \
  "$ROOT_DIR"/ui/*.sh \
  "$ROOT_DIR"/workflows/*.sh \
  "$ROOT_DIR"/books/*.sh \
  "$ROOT_DIR"/recommendations/*.sh \
  "$ROOT_DIR"/data/*.sh; do
  if bash -n "$script"; then :; else fail "syntax: ${script#$ROOT_DIR/}"; fi
done
pass "all Bash files parse"

"$ROOT_DIR/data/book_database.sh" init

metadata="$(printf 'The Alignment Problem|Brian Christian\n' | "$ROOT_DIR/books/fetch_book_metadata.sh")"
assert_contains "metadata enrichment through stdin" "$metadata" "Technology|2020|496|deep"

unknown="$("$ROOT_DIR/books/fetch_book_metadata.sh" "A Small Unknown Book" "A. Reader")"
assert_contains "unknown metadata remains predictable" "$unknown" "A Small Unknown Book|A. Reader|Uncategorized"

add_output="$("$ROOT_DIR/workflows/manage_library.sh" add 'The Design of Everyday Things|Don Norman|finished|4.5')"
assert_contains "add workflow crosses component boundary" "$add_output" "Added The Design of Everyday Things"

if ! "$ROOT_DIR/data/book_database.sh" add \
  "The Design of Everyday Things" "Don Norman" "Design" "2013" "368" "owned" "" "thoughtful" "" >/dev/null 2>&1; then
  pass "duplicate prevention"
else
  fail "duplicate prevention"
fi

if ! "$ROOT_DIR/data/book_database.sh" add \
  "Bad Rating" "Test Author" "Test" "2020" "200" "finished" "5.5" "brisk" "" >/dev/null 2>&1; then
  pass "rating validation"
else
  fail "rating validation"
fi

if ! "$ROOT_DIR/data/book_database.sh" add \
  "Bad Status" "Test Author" "Test" "2020" "200" "someday" "" "brisk" "" >/dev/null 2>&1; then
  pass "status validation"
else
  fail "status validation"
fi

search_output="$(printf 'design\n' | "$ROOT_DIR/books/search_books.sh")"
assert_contains "search component accepts a pipe" "$search_output" "The Design of Everyday Things"

"$ROOT_DIR/workflows/manage_library.sh" update-status "The Design of Everyday Things" "reading" >/dev/null
"$ROOT_DIR/workflows/manage_library.sh" rate "The Design of Everyday Things" "5" >/dev/null
updated="$("$ROOT_DIR/data/book_database.sh" search "Everyday")"
assert_contains "status and rating updates" "$updated" "|reading|5|thoughtful|"

stats="$("$ROOT_DIR/data/book_database.sh" stats)"
assert_contains "dashboard statistics" "$stats" "total|1"
assert_contains "average rating calculation" "$stats" "average-rating|5.0"

"$ROOT_DIR/data/book_database.sh" add \
  "Thinking in Systems" "Donella H. Meadows" "Systems" "2008" "240" "finished" "5" "thoughtful" "" >/dev/null
"$ROOT_DIR/data/book_database.sh" add \
  "Co-Intelligence" "Ethan Mollick" "Technology" "2024" "256" "reading" "" "brisk" "" >/dev/null

candidates='99|Thinking in Systems|Donella H. Meadows|Systems|2008|240|thoughtful|history|already saved|https://example.com/saved
92|Novel A|Writer A|Fiction|2020|220|thoughtful|interests|first copy|https://example.com/a
91|Novel A|Writer A|Fiction|2020|220|brisk|discovery|duplicate copy|https://example.com/a
90|Novel B|Writer B|Fiction|2021|260|thoughtful|discovery|second genre result|https://example.com/b
89|Novel C|Writer C|Fiction|2022|280|thoughtful|discovery|third genre result|https://example.com/c
88|Essay D|Writer D|Essays|2023|180|brisk|interests|fresh genre|https://example.com/d'
refined="$(printf '%s\n' "$candidates" | "$ROOT_DIR/recommendations/refine_recommendations.sh")"
assert_contains "refinement keeps unseen candidates" "$refined" "Novel A"
assert_not_contains "refinement excludes saved books" "$refined" "Thinking in Systems"
if [ "$(printf '%s\n' "$refined" | grep -c 'Novel A')" -eq 1 ]; then pass "refinement deduplicates"; else fail "refinement deduplicates"; fi
if [ "$(printf '%s\n' "$refined" | grep -c '|Fiction|')" -le 2 ]; then pass "refinement enforces genre diversity"; else fail "refinement enforces genre diversity"; fi

recommendations="$("$ROOT_DIR/workflows/get_recommendations.sh" --non-interactive)"
assert_contains "parallel history reader completes" "$recommendations" "History reader finished"
assert_contains "parallel interest reader completes" "$recommendations" "Interest reader finished"
assert_contains "parallel discovery reader completes" "$recommendations" "Discovery reader finished"
assert_contains "recommendation shortlist displays" "$recommendations" "1. "
assert_not_contains "shortlist excludes existing catalog books" "$recommendations" "Thinking in Systems -"

if grep -Fq '&' "$ROOT_DIR/workflows/get_recommendations.sh" \
  && grep -Fq '$!' "$ROOT_DIR/workflows/get_recommendations.sh" \
  && grep -Fq 'wait "$history_pid"' "$ROOT_DIR/workflows/get_recommendations.sh" \
  && grep -Fq '| "$ROOT_DIR/recommendations/refine_recommendations.sh"' "$ROOT_DIR/workflows/get_recommendations.sh"; then
  pass "workflow visibly demonstrates &, \$!, wait, and a pipe"
else
  fail "workflow visibly demonstrates &, \$!, wait, and a pipe"
fi

shell_refs="$(grep -l 'books\.csv' \
  "$ROOT_DIR/app.sh" "$ROOT_DIR"/data/*.sh "$ROOT_DIR"/books/*.sh \
  "$ROOT_DIR"/recommendations/*.sh "$ROOT_DIR"/ui/*.sh "$ROOT_DIR"/workflows/*.sh \
  | sed "s|$ROOT_DIR/||")"
if [ "$shell_refs" = "data/book_database.sh" ]; then
  pass "database access boundary"
else
  fail "database access boundary"
  printf '  Unexpected references: %s\n' "$shell_refs" >&2
fi

if grep -Rqs 'gum choose' "$ROOT_DIR/ui" && grep -Rqs 'gum input' "$ROOT_DIR/ui" && grep -Rqs 'gum style' "$ROOT_DIR/ui"; then
  pass "Gum menu, selection, input, and styling"
else
  fail "Gum menu, selection, input, and styling"
fi

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
