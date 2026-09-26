import AppKit
import SwiftUI

@main
@MainActor
struct LayoutCheck {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WooHooDooLayout-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let previewFile = ProcessInfo.processInfo.environment["WOOHOODOO_LAYOUT_FILE"]
        let clips = [
            Clip(id: UUID(), kind: .text,
                 text: "func greet(name: String) -> String {\n    return \"Hello, \\(name)\"\n}",
                 imageName: nil, filePaths: nil, fingerprint: "code",
                 createdAt: .now, isPinned: true),
            Clip(id: UUID(), kind: .text,
                 text: "Design notes for the new utility panel",
                 imageName: nil, filePaths: nil, fingerprint: "notes",
                 createdAt: Date().addingTimeInterval(-3600), isPinned: false),
            Clip(id: UUID(), kind: .files,
                 text: previewFile.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Demo.mov",
                 imageName: nil, filePaths: [previewFile ?? "/tmp/Demo.mov"],
                 fingerprint: "video", createdAt: Date().addingTimeInterval(-86400),
                 isPinned: false),
        ]
        let state = SavedState(clips: clips, isPaused: false, retentionDays: 30, maxItems: 200)
        try JSONEncoder().encode(state).write(to: directory.appendingPathComponent("history.json"))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("WooHooDooLayout-\(UUID())"))
        let store = ClipboardStore(pasteboard: pasteboard, directory: directory, startsPolling: false)
        let controller = AppController(store: store)
        if previewFile != nil { controller.selectedIndex = 2 }
        let app = NSApplication.shared
        app.applicationIconImage = NSImage(contentsOfFile: "dist/WooHooDoo.app/Contents/Resources/AppIcon.icns")
        app.setActivationPolicy(.regular)
        let window = NSPanel(contentRect: NSRect(origin: .zero, size: AppController.panelSize),
                             styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = NSHostingView(rootView: HistoryView(controller: controller))
        window.minSize = AppController.panelSize
        window.maxSize = AppController.panelSize
        window.setFrame(NSRect(origin: .zero, size: AppController.panelSize), display: false)
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)

        let prefix = CommandLine.arguments[1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            save(window: window, path: prefix + "-history.png")
            controller.showSettings = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                save(window: window, path: prefix + "-settings.png")
                controller.showSettings = false
                window.appearance = NSAppearance(named: .darkAqua)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    save(window: window, path: prefix + "-dark.png")
                    app.terminate(nil)
                }
            }
        }
        withExtendedLifetime((controller, window)) { app.run() }
    }

    private static func save(window: NSWindow, path: String) {
        precondition(abs(window.frame.width - AppController.panelSize.width) < 1 &&
                     abs(window.frame.height - AppController.panelSize.height) < 1,
                     "Panel changed size while rendering")
        guard let view = window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }

    private struct SavedState: Codable {
        let clips: [Clip]
        let isPaused: Bool
        let retentionDays: Int
        let maxItems: Int
    }
}
