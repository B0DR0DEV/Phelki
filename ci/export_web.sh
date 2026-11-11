#!/usr/bin/env bash
# Собирает веб-версию в build/web (index.html + файлы игры) для GitHub Pages.
set -euo pipefail

mkdir -p build/web
godot --headless --path . --import
godot --headless --path . --export-release "Web" build/web/index.html
test -s build/web/index.html
test -s build/web/index.pck
ls -la build/web
