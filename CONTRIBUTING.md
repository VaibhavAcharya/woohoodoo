# Contributing

WooHooDoo is a macOS app built with SwiftUI and AppKit. Read the [README](README.md) for installation and shortcuts, and the [architecture notes](docs/ARCHITECTURE.md) for capture and storage behavior.

Keep changes focused. Explain the user-facing behavior and any storage or permission changes in your pull request. For clipboard changes, run `./scripts/check.sh`. Run `./scripts/build-app.sh` for app code or build script changes.

For UI changes, build the app first so the renderer can load its icon, then render and inspect the sample screens:

```sh
./scripts/build-app.sh
./scripts/check-layout.sh
```

The layout script captures the sample window through macOS `screencapture`. macOS may require Screen Recording access for the terminal running it. It renders history, settings, dark appearance, video playback, GIF preview, and search to `.build/layout-*.png`. When the public interface changes, copy the affected captures to `docs/screenshots/`. The video and GIF captures use the generated sample files in `docs/fixtures/`.

Use sample clips in screenshots and bug reports. Clipboard history can contain private text, images, and file paths.
