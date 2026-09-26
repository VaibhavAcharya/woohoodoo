# Repository guide

Read `README.md` and `docs/ARCHITECTURE.md` before changing the app. Keep changes focused and follow the SwiftUI and AppKit patterns already in the codebase.

## Project map

- `Sources/WooHooDoo/AppController.swift`: menu bar, panel, keyboard input, paste, and launch at login.
- `Sources/WooHooDoo/Clipboard/`: capture, storage, history, previews, and settings.
- `scripts/`: build, install, checks, icon generation, and sample screen rendering.
- `docs/screenshots/`: public screenshots generated with sample clips.

## Checks

Run `./scripts/check.sh` for clipboard storage changes. Run `./scripts/build-app.sh` before `./scripts/check-layout.sh` for UI changes, then inspect the images in `.build/`. Run the build for app code or build script changes. These commands require macOS; the build also needs Apple's Swift command-line tools and Python 3.

Keep screenshots free of personal clipboard data. Use the sample screen renderer to update public screenshots. Preserve the app's bundle identifier and existing history format unless a change explicitly includes migration. Do not commit, push, or open a pull request without the owner's explicit instruction.
