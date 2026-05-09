#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPORT_DIR="$PROJECT_DIR/exports"
GODOT="${GODOT_BIN:-godot}"

mkdir -p "$EXPORT_DIR"

echo "==> Exporting for Linux..."
$GODOT --headless --path "$PROJECT_DIR" --export-release "Linux" "$EXPORT_DIR/chess-game-linux.x86_64" 2>&1

echo "==> Exporting for Windows..."
$GODOT --headless --path "$PROJECT_DIR" --export-release "Windows" "$EXPORT_DIR/chess-game-win.exe" 2>&1

echo "==> Done! Builds in: $EXPORT_DIR"
ls -lh "$EXPORT_DIR"
