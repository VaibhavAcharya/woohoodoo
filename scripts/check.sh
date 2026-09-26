#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
mkdir -p .build/clang-cache
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-cache"
swiftc -parse-as-library Sources/WooHooDoo/Clipboard/ClipboardStore.swift \
    scripts/check-clipboard-store.swift -o .build/check-clipboard-store
.build/check-clipboard-store
