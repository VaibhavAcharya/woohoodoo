#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
mkdir -p .build/clang-cache
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-cache"
swiftc -parse-as-library -D LAYOUT_CHECK Sources/WooHooDoo/AppIcon.swift Sources/WooHooDoo/GlassStyles.swift Sources/WooHooDoo/AppController.swift \
    Sources/WooHooDoo/Clipboard/*.swift scripts/render-layout.swift -o .build/render-layout

renderer_pid=""
id_file=""
cleanup() {
    if [[ -n "$renderer_pid" ]]; then
        kill "$renderer_pid" 2>/dev/null || true
        wait "$renderer_pid" 2>/dev/null || true
    fi
    if [[ -n "$id_file" ]]; then rm -f "$id_file"; fi
}
trap cleanup EXIT

for scenario in light settings dark video gif search; do
    id_file="$(mktemp "$project_dir/.build/layout-id.XXXXXX")"
    .build/render-layout "$scenario" >"$id_file" &
    renderer_pid=$!
    window_id=""
    for ((attempt = 0; attempt < 100; attempt++)); do
        if [[ -s "$id_file" ]]; then
            read -r _ _ _ window_id <"$id_file"
            break
        fi
        if ! kill -0 "$renderer_pid" 2>/dev/null; then break; fi
        sleep 0.1
    done
    if [[ ! "$window_id" =~ ^[0-9]+$ ]]; then
        echo "Could not open the $scenario sample window." >&2
        exit 1
    fi

    case "$scenario" in
        light) output="$project_dir/.build/layout-history.png" ;;
        settings) output="$project_dir/.build/layout-settings.png" ;;
        dark) output="$project_dir/.build/layout-dark.png" ;;
        video) output="$project_dir/.build/layout-video.png" ;;
        gif) output="$project_dir/.build/layout-gif.png" ;;
        search) output="$project_dir/.build/layout-search.png" ;;
    esac
    rm -f "$output"
    if ! screencapture -x -l"$window_id" "$output"; then
        echo "Could not capture the $scenario sample window. Check macOS Screen Recording access for this terminal." >&2
        exit 1
    fi
    if [[ ! -s "$output" ]]; then
        echo "Could not capture the $scenario sample window." >&2
        exit 1
    fi
    kill "$renderer_pid"
    wait "$renderer_pid" || true
    renderer_pid=""
    rm -f "$id_file"
    id_file=""
done
