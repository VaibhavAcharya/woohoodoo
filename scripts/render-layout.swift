import AppKit
import AVKit
import Darwin
import SwiftUI

@main
@MainActor
struct LayoutCheck {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WooHooDooLayout-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let scenario = CommandLine.arguments.dropFirst().first ?? "light"
        precondition(["light", "dark", "settings", "video", "gif", "search"].contains(scenario))
        let previewFile = ProcessInfo.processInfo.environment["WOOHOODOO_LAYOUT_FILE"]
        let imageName = try makeSampleImage(in: directory)
        let videoURL = directory.appendingPathComponent("Demo.mp4")
        let gifURL = directory.appendingPathComponent("animation.gif")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "docs/fixtures/preview.mp4"), to: videoURL)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "docs/fixtures/preview.gif"), to: gifURL)
        let code = """
        struct ClipboardHistory {
            private(set) var clips: [Clip] = []

            mutating func capture(_ clip: Clip) {
                clips.removeAll { $0.id == clip.id }
                clips.insert(clip, at: 0)
            }

            func search(_ query: String) -> [Clip] {
                clips.filter { clip in
                    clip.text.localizedCaseInsensitiveContains(query)
                }
            }
        }
        """
        func textClip(_ text: String, minutesAgo: TimeInterval, pinned: Bool = false) -> Clip {
            Clip(id: UUID(), kind: .text, text: text, imageName: nil, filePaths: nil,
                 fingerprint: UUID().uuidString, createdAt: .now.addingTimeInterval(-minutesAgo * 60),
                 isPinned: pinned)
        }
        func fileClip(_ name: String, minutesAgo: TimeInterval, path: String? = nil) -> Clip {
            Clip(id: UUID(), kind: .files, text: name, imageName: nil,
                 filePaths: [path ?? "/tmp/\(name)"], fingerprint: UUID().uuidString,
                 createdAt: .now.addingTimeInterval(-minutesAgo * 60), isPinned: false)
        }
        var clips = [
            Clip(id: UUID(), kind: .image, text: "Image", imageName: imageName,
                 filePaths: nil, fingerprint: "sample-image",
                 createdAt: .now.addingTimeInterval(-120), isPinned: false),
            textClip(code, minutesAgo: 5, pinned: true),
            fileClip(previewFile.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Demo.mp4",
                     minutesAgo: 18, path: previewFile ?? videoURL.path),
            textClip("https://example.com/design-notes", minutesAgo: 31),
            textClip("Project notes\n- Keep the clipboard easy to scan\n- Preview before pasting",
                     minutesAgo: 65),
            fileClip("project-brief.pdf", minutesAgo: 120),
            fileClip("animation.gif", minutesAgo: 360, path: gifURL.path),
            textClip("swift build -c release", minutesAgo: 900),
            fileClip("layout-reference.png", minutesAgo: 1440),
            textClip("A short sample sentence to copy later.", minutesAgo: 2880),
        ]
        if scenario == "gif" { clips.insert(clips.remove(at: 6), at: 0) }
        let state = SavedState(clips: clips, isPaused: false, retentionDays: 30, maxItems: 200)
        try JSONEncoder().encode(state).write(to: directory.appendingPathComponent("history.json"))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("WooHooDooLayout-\(UUID())"))
        let store = ClipboardStore(pasteboard: pasteboard, directory: directory, startsPolling: false)
        let controller = AppController(store: store)
        controller.selectedIndex = switch scenario {
        case "dark": 1
        case "video": 2
        case "gif": 0
        default: previewFile == nil ? 0 : 2
        }
        if scenario == "search" { controller.query = "clipboard" }
        controller.showSettings = scenario == "settings"
        let app = NSApplication.shared
        app.applicationIconImage = NSImage(contentsOfFile: "dist/WooHooDoo.app/Contents/Resources/AppIcon.icns")
        app.setActivationPolicy(.regular)
        let backdrop = NSWindow(contentRect: NSRect(origin: .zero,
                                                   size: NSSize(width: AppController.panelSize.width + 160,
                                                                height: AppController.panelSize.height + 160)),
                                styleMask: [.borderless], backing: .buffered, defer: false)
        backdrop.backgroundColor = scenario == "dark"
            ? NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.20, alpha: 1)
            : NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.95, alpha: 1)
        backdrop.hasShadow = false
        backdrop.level = .floating
        backdrop.center()
        backdrop.orderFront(nil)
        let window = NSPanel(contentRect: NSRect(origin: .zero, size: AppController.panelSize),
                             styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: scenario == "dark" ? .darkAqua : .aqua)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isFloatingPanel = true
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        window.hasShadow = true
        window.contentView = NSHostingView(rootView: HistoryView(controller: controller))
        window.minSize = AppController.panelSize
        window.maxSize = AppController.panelSize
        window.setFrame(NSRect(origin: .zero, size: AppController.panelSize), display: false)
        window.setFrameOrigin(NSPoint(x: backdrop.frame.midX - window.frame.width / 2,
                                      y: backdrop.frame.midY - window.frame.height / 2))
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)

        if scenario == "video" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if let contentView = window.contentView {
                    playerView(in: contentView)?.player?.play()
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            precondition(abs(window.frame.width - AppController.panelSize.width) < 1 &&
                         abs(window.frame.height - AppController.panelSize.height) < 1,
                         "Panel changed size while rendering \(scenario): \(window.frame)")
            precondition(backdrop.screen?.visibleFrame.contains(backdrop.frame) == true,
                         "Sample backdrop does not fit on screen")
            let frame = backdrop.frame
            let screenTop = NSScreen.screens[0].frame.maxY
            let region = "\(Int(frame.minX)),\(Int(screenTop - frame.maxY)),\(Int(frame.width)),\(Int(frame.height))"
            FileHandle.standardOutput.write(Data("Sample capture region: \(region)\n".utf8))
        }
        signal(SIGTERM, SIG_IGN)
        let terminate = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        terminate.setEventHandler { app.terminate(nil) }
        terminate.resume()
        withExtendedLifetime((controller, window, backdrop, terminate)) { app.run() }
    }

    private static func playerView(in view: NSView) -> AVPlayerView? {
        if let playerView = view as? AVPlayerView { return playerView }
        return view.subviews.lazy.compactMap { playerView(in: $0) }.first
    }

    private static func makeSampleImage(in directory: URL) throws -> String {
        let name = "sample-image.png"
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: 640, height: 360, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: colorSpace,
                                        colors: [NSColor.systemIndigo.cgColor,
                                                 NSColor.systemTeal.cgColor] as CFArray,
                                        locations: [0, 1]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 640, y: 360), options: [])
        context.setFillColor(NSColor.white.withAlphaComponent(0.2).cgColor)
        context.fillEllipse(in: CGRect(x: 100, y: 45, width: 250, height: 250))
        context.fillEllipse(in: CGRect(x: 350, y: 140, width: 140, height: 140))
        guard let image = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: directory.appendingPathComponent(name))
        return name
    }

    private struct SavedState: Codable {
        let clips: [Clip]
        let isPaused: Bool
        let retentionDays: Int
        let maxItems: Int
    }
}
