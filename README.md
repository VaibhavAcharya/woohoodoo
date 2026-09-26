# WooHooDoo

WooHooDoo is a free and open source clipboard history app for macOS. Press `Command-Shift-V` to search, preview, and paste a clip. It runs from the menu bar, and your history stays on your Mac.

![WooHooDoo clipboard history in light appearance](docs/screenshots/history-light.png)

| Video playing with native controls | GIF preview |
| --- | --- |
| ![Video playing in the preview pane with pause and timeline controls](docs/screenshots/video-preview.png) | ![Animated GIF file in the preview pane](docs/screenshots/gif-preview.png) |

| Search and pinned clips | Dark appearance |
| --- | --- |
| ![Clipboard search results with a pinned code clip](docs/screenshots/search.png) | ![Clipboard history in dark appearance](docs/screenshots/history-dark.png) |

![Clipboard retention and capture settings](docs/screenshots/settings-light.png)

## Why I built this

I used Raycast only for clipboard history, and it used more RAM than I wanted for that one feature. The dedicated apps I found cost around $15, so I built my own. It's free and open source. I might add other utilities as I need them.

## What it does

- Keeps a searchable history of text, images, and file paths. The latest clip stays on top.
- Filters by pinned clips, text, images, or files.
- Previews text, code, images, animated GIFs, and video. Quick Look handles other supported files.
- Pins clips, pauses capture, and lets you set retention limits.
- Opens from the menu bar or a keyboard shortcut. Launch at login is optional.

WooHooDoo needs no account and makes no network requests.

## Size and memory

The release app bundle is **1.9 MB**. On 26 September 2026, a one-minute idle test on Apple silicon with macOS 27.0 and 14 saved clips measured **69.6 MB physical footprint** (`vmmap`) and **114 MB RSS** (`ps`). The window was closed; open previews and larger histories can use more memory.

## Install

You need macOS 14 or later, Apple's Swift command-line tools, and Python 3. From this repository, run:

```sh
./scripts/install-app.sh
```

The script builds an ad hoc signed app, installs it at `~/Applications/WooHooDoo.app`, and opens it. Quit WooHooDoo before running the script again to update it. The app appears in the menu bar, not the Dock. You can also open it from `~/Applications`.

For a build without installation, run `./scripts/build-app.sh` and open `dist/WooHooDoo.app`.

## Use

Press `Command-Shift-V` or click the WooHooDoo menu bar icon. Search, use the filters, and select a clip with the arrow keys. Copying or pasting a saved clip moves it to the top and refreshes its retention date.

| Shortcut | Action |
| --- | --- |
| `Command-Shift-V` | Open or close WooHooDoo |
| `Up` / `Down` | Move through results |
| `Return` | Paste the selected clip |
| `Command-Return` | Copy the selected clip |
| `Command-.` | Pin or unpin the selected clip |
| `Command-X` | Delete the selected clip |
| `Escape` | Close the panel or settings |

Double-clicking a result also pastes it. Automatic paste needs macOS Accessibility access. Without it, WooHooDoo puts the clip on the clipboard and asks for access; you can paste manually.

GIF files play automatically in the preview. Copied GIF images also play when the source app puts the original GIF data on the clipboard. If it only supplies a still image, WooHooDoo cannot recover the animation.

Open the gear button to change retention and capture settings. To start the app when you sign in, enable **Launch WooHooDoo at login** there. macOS may ask you to approve the login item in System Settings. Keep the installed app in `~/Applications` while this setting is enabled.

## Retention and privacy

Unpinned history defaults to **30 days** and **200 clips**. Settings offer other limits, including Forever and Unlimited. Pinned clips stay until you delete them. WooHooDoo applies limits when it captures a clip, starts, or changes settings, and about once an hour while running.

History lives in `~/Library/Application Support/WooHooDoo`. Text and copied images are saved there. Files are saved as paths to the originals, so their previews stop working if the originals move or are deleted. Text over 1 MB, images over 10 MB, and clipboard entries marked concealed or transient are skipped. The stored history is not encrypted; anyone with access to your macOS account can read it.

## Uninstall

Turn off **Launch WooHooDoo at login** in settings, quit the app from its `...` menu, and move `~/Applications/WooHooDoo.app` to Trash. To erase saved history and settings, also delete `~/Library/Application Support/WooHooDoo`. The local `dist/` build and repository can be removed separately.

## Development

| Command | Purpose |
| --- | --- |
| `./scripts/build-app.sh` | Build and sign `dist/WooHooDoo.app` locally |
| `./scripts/check.sh` | Run clipboard storage checks |
| `./scripts/check-layout.sh` | Render sample screens to `.build/layout-*.png` |

WooHooDoo is built with SwiftUI and AppKit, with no third-party packages. Read [architecture](docs/ARCHITECTURE.md) for the data flow and storage, and [contributing](CONTRIBUTING.md) before sending a change. Header controls use Liquid Glass on macOS 26 and later.

## License

[MIT](LICENSE) © 2026 Vaibhav Acharya.
