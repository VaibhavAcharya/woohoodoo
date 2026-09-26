#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
if pgrep -x WooHooDoo >/dev/null; then
    echo "Quit WooHooDoo before installing an update."
    exit 1
fi
"$project_dir/scripts/build-app.sh"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/WooHooDoo.app"
ditto "$project_dir/dist/WooHooDoo.app" "$HOME/Applications/WooHooDoo.app"
open "$HOME/Applications/WooHooDoo.app"
