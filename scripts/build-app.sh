#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-cache"

swift build -c release --disable-sandbox --cache-path .build/cache
binary_dir="$(swift build -c release --disable-sandbox --cache-path .build/cache --show-bin-path)"
app_dir="$project_dir/dist/WooHooDoo.app"
mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
cp "$binary_dir/WooHooDoo" "$app_dir/Contents/MacOS/WooHooDoo"
cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
icon_dir="$project_dir/.build/AppIcon.iconset"
mkdir -p "$icon_dir"
swift "$project_dir/scripts/make-icon.swift" "$icon_dir/icon_512x512@2x.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$icon_dir/icon_512x512@2x.png" --out "$icon_dir/icon_${size}x${size}.png" >/dev/null
    doubled_size=$((size * 2))
    sips -z "$doubled_size" "$doubled_size" "$icon_dir/icon_512x512@2x.png" --out "$icon_dir/icon_${size}x${size}@2x.png" >/dev/null
done
python3 "$project_dir/scripts/build-icon.py" "$icon_dir" "$app_dir/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app_dir"
echo "$app_dir"
