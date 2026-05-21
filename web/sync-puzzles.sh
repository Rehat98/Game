#!/usr/bin/env bash
# Sync the web copy of puzzles.json and sounds from the iOS source of truth.
# Run after editing Pictok/Resources/puzzles.json or Pictok/Resources/Sounds/.
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cp "$REPO_ROOT/Pictok/Resources/puzzles.json" "$SCRIPT_DIR/puzzles.json"
cp "$REPO_ROOT/Pictok/Resources/Sounds/"*.wav "$SCRIPT_DIR/sounds/"
echo "Synced $(jq length "$SCRIPT_DIR/puzzles.json" 2>/dev/null || echo '?') puzzles + $(ls "$SCRIPT_DIR/sounds/"*.wav | wc -l | tr -d ' ') sounds → web/"
