# WooHooDoo architecture

## App shell

`AppController.swift` owns the menu-bar item, floating panel, global `Command-Shift-V` hotkey, keyboard navigation, paste action, and macOS login item setting. The app has no Dock icon. The clipboard feature lives under `Sources/WooHooDoo/Clipboard/`, so later utilities can add their own views and storage without changing the app identity.

`HistoryView.swift` provides the search-first, two-column filter, selection, and preview layout. Row timestamps update by minute. The `NSPanel` uses `AppController.panelSize`; the SwiftUI root fills the panel frame and extends through its titlebar safe area, so history and settings keep the same window size. The preview column has a fixed width so search results with long text cannot push actions outside the panel. The controller restores the panel size if AppKit resizes it. `GlassStyles.swift` applies Liquid Glass to header controls on macOS 26 and later. `PreviewPane.swift` uses `AVPlayerView` for common video files, `NSImageView` for still and animated images, and `QLPreviewView` for other files that macOS Quick Look supports. Image and video views have no intrinsic size so large media cannot expand the panel. Small UTF-8 code and text files render as selectable monospaced text. `SettingsView.swift` controls retention, capture, and launch at login.

## Clipboard capture

`ClipboardStore` checks `NSPasteboard.general.changeCount` every 0.5 seconds. It ignores pasteboard entries marked concealed, transient, or auto-generated. On a change, it checks file URLs first, then original GIF data, text, and other images. GIF data stays in its original format so animated frames remain available. Other images are saved as PNG. It deduplicates by SHA-256 content fingerprint. Restoring a clip updates the pasteboard change count so the app does not capture its own paste again.

The selected clip is written back to the system pasteboard before the previous app is activated. Copying a saved clip moves it to the top of history and refreshes its retention date. A synthetic `Command-V` needs Accessibility permission. When permission is unavailable, the clip remains on the pasteboard for manual paste.

The **Paste and Keep Open** button and `Command-Shift-Return` keep the panel visible while the previous app receives the paste, then return keyboard focus to the panel. The search and filter stay in place, and the pasted clip stays selected after moving to the top of history. Pin, Delete, and Copy use compact icon and shortcut controls with tooltips and accessibility labels.

## Storage and retention

`~/Library/Application Support/WooHooDoo/history.json` stores clip metadata, text, pause state, and retention settings. Copied images are separate files in the same folder. Finder files are stored as paths and are not duplicated. Removing an image clip removes its image file.

The default retention is 30 days and 200 unpinned clips. Pinned clips are excluded from both limits. Changes to retention prune immediately; startup and the hourly check prune expired items. Settings and history are written atomically. Older history files without retention fields load with the current defaults.

This JSON model keeps the entire history in memory. It fits the default 200-item limit. If a later utility needs a much larger or unlimited history, move storage to SQLite and query pages rather than growing the in-memory array.

## Build and checks

`Package.swift` is the Swift package entry point. `scripts/build-app.sh` compiles the release executable, creates the app bundle and icon, then signs it locally. `scripts/install-app.sh` replaces the bundle in `~/Applications` and opens it. `scripts/check.sh` compiles `ClipboardStore` with isolated checks covering retention, pins, file references, and concealed content. `scripts/check-layout.sh` opens isolated sample windows for history, settings, dark appearance, video playback, GIF preview, and search, then captures each window through macOS `screencapture`. The public images in `docs/screenshots/` come from this workflow. Video and GIF samples in `docs/fixtures/` are generated media and contain no personal data.

The app does not yet save rich text representations or offer per-app capture exclusions. Quick Look support depends on macOS and the original file remaining available.
