import AppKit
import ApplicationServices
import Carbon
import ServiceManagement
import SwiftUI

enum ClipFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pinned = "Pinned"
    case text = "Text"
    case images = "Images"
    case files = "Files"

    var id: Self { self }
}

@MainActor
final class AppController: NSObject, ObservableObject, NSApplicationDelegate, NSWindowDelegate {
    static let panelSize = NSSize(width: 860, height: 580)

    let store: ClipboardStore
    @Published var query = ""
    @Published var selectedIndex = 0
    @Published var presentationCount = 0
    @Published var showClearConfirmation = false
    @Published var showSettings = false
    @Published var filter: ClipFilter = .all {
        didSet { selectedIndex = 0 }
    }
    @Published var selectedFileIndex = 0
    @Published private(set) var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    @Published var loginItemError: String?

    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var keyMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var previousApp: NSRunningApplication?

    var filteredClips: [Clip] {
        store.clips.filter { clip in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .pinned: matchesFilter = clip.isPinned
            case .text: matchesFilter = clip.kind == .text
            case .images: matchesFilter = clip.kind == .image
            case .files: matchesFilter = clip.kind == .files
            }
            return matchesFilter && (query.isEmpty || clip.text.localizedCaseInsensitiveContains(query))
        }
    }

    var selectedClip: Clip? {
        let clips = filteredClips
        return clips.indices.contains(selectedIndex) ? clips[selectedIndex] : clips.last
    }

    init(store: ClipboardStore? = nil) {
        self.store = store ?? ClipboardStore()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = AppIcon.image ?? NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "WooHooDoo")
        item.button?.image?.size = NSSize(width: 18, height: 18)
        item.button?.toolTip = "WooHooDoo"
        item.button?.target = self
        item.button?.action = #selector(toggleWindow)
        statusItem = item

        let window = NSPanel(contentRect: NSRect(origin: .zero, size: Self.panelSize),
                             styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = false
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self
        window.contentView = NSHostingView(rootView: HistoryView(controller: self))
        window.minSize = Self.panelSize
        window.maxSize = Self.panelSize
        window.setFrame(NSRect(origin: .zero, size: Self.panelSize), display: false)
        panel = window

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isVisible == true, event.window === self.panel else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasCommand = modifiers.contains(.command)
            let hasOtherModifiers = !modifiers.intersection([.shift, .option, .control]).isEmpty
            if !self.showSettings, hasCommand, !hasOtherModifiers {
                switch event.keyCode {
                case UInt16(kVK_ANSI_Period):
                    if !event.isARepeat { self.togglePinSelected() }
                    return nil
                case UInt16(kVK_ANSI_X):
                    if !event.isARepeat { self.deleteSelected() }
                    return nil
                case 36: self.copySelected(); return nil
                default: break
                }
            }
            switch event.keyCode {
            case 53:
                if self.showSettings { self.showSettings = false } else { self.hide() }
                return nil
            case 125 where !self.showSettings: self.moveSelection(by: 1); return nil
            case 126 where !self.showSettings: self.moveSelection(by: -1); return nil
            case 36 where !self.showSettings: self.pasteSelected(); return nil
            default: return event
            }
        }
        installHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    @objc private func toggleWindow() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    func show() {
        guard let panel else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        query = ""
        selectedIndex = 0
        selectedFileIndex = 0
        showSettings = false
        if let frame = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2,
                                         y: frame.maxY - panel.frame.height - 76))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        presentationCount += 1
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    func moveSelection(by offset: Int) {
        let count = filteredClips.count
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), count - 1)
    }

    func pasteSelected() {
        guard let selectedClip else { return }
        paste(selectedClip)
    }

    func copySelected() {
        guard let selectedClip else { return }
        copy(selectedClip)
    }

    func copy(_ clip: Clip) {
        guard store.copy(clip) else { return }
        select(clip)
    }

    func togglePinSelected() {
        guard let selectedClip else { return }
        togglePin(selectedClip)
    }

    func deleteSelected() {
        guard let selectedClip else { return }
        delete(selectedClip)
    }

    func togglePin(_ clip: Clip) {
        store.togglePin(clip)
        keepSelectionInRange()
    }

    func delete(_ clip: Clip) {
        store.delete(clip)
        keepSelectionInRange()
    }

    private func keepSelectionInRange() {
        selectedIndex = min(selectedIndex, max(filteredClips.count - 1, 0))
    }

    func select(_ clip: Clip) {
        if let index = filteredClips.firstIndex(where: { $0.id == clip.id }) {
            selectedIndex = index
            selectedFileIndex = 0
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func paste(_ clip: Clip) {
        guard store.copy(clip) else { return }
        hide()
        guard let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousApp.activate(options: [])
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            down?.flags = .maskCommand
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    private func installHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let controller = Unmanaged<AppController>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { controller.toggleWindow() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)

        let id = EventHotKeyID(signature: 0x434B4550, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey),
                                         id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if result != noErr { NSLog("WooHooDoo could not register Command-Shift-V: %d", result) }
    }
}

#if !LAYOUT_CHECK
@main
struct WooHooDooApp {
    static func main() {
        let app = NSApplication.shared
        let controller = AppController()
        app.delegate = controller
        withExtendedLifetime(controller) { app.run() }
    }
}
#endif
