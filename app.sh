#!/usr/bin/env bash

# Curious Shelf entry point. Application behavior lives in the layers below.
set -u

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$ROOT_DIR/data/book_database.sh" init
exec "$ROOT_DIR/ui/main_menu.sh"
