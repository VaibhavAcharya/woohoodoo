#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
mkdir -p .build/clang-cache
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-cache"
swiftc -parse-as-library -D LAYOUT_CHECK Sources/WooHooDoo/AppIcon.swift Sources/WooHooDoo/GlassStyles.swift Sources/WooHooDoo/AppController.swift \
    Sources/WooHooDoo/Clipboard/*.swift scripts/render-layout.swift -o .build/render-layout
.build/render-layout "$project_dir/.build/layout"
