import AppKit
import CryptoKit
import UniformTypeIdentifiers

enum ClipKind: String, Codable {
    case text
    case image
    case files
}

struct Clip: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: ClipKind
    let text: String
    let imageName: String?
    let filePaths: [String]?
    let fingerprint: String
    var createdAt: Date
    var isPinned: Bool
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var clips: [Clip] = []
    @Published var isPaused = false {
        didSet { if !isLoading { save() } }
    }
    @Published var retentionDays = 30 {
        didSet { if !isLoading { pruneAndSave() } }
    }
    @Published var maxItems = 200 {
        didSet { if !isLoading { pruneAndSave() } }
    }

    private struct SavedState: Codable {
        var clips: [Clip]
        var isPaused: Bool
        var retentionDays: Int?
        var maxItems: Int?
    }

    private let pasteboard: NSPasteboard
    private let directory: URL
    private var lastChangeCount: Int
    private var lastPruneDate = Date()
    private var isLoading = false
    private var timer: Timer?

    init(pasteboard: NSPasteboard = .general, directory: URL? = nil, startsPolling: Bool = true) {
        self.pasteboard = pasteboard
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory,
                                                                 in: .userDomainMask)[0]
            .appendingPathComponent("WooHooDoo", isDirectory: true)
        lastChangeCount = pasteboard.changeCount
        load()
        if startsPolling {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.captureNow() }
            }
        }
    }

    func image(for clip: Clip) -> NSImage? {
        guard let imageName = clip.imageName else { return nil }
        return NSImage(contentsOf: directory.appendingPathComponent(imageName))
    }

    func fileURLs(for clip: Clip) -> [URL] {
        (clip.filePaths ?? []).map { URL(fileURLWithPath: $0) }
    }

    func canRestore(_ clip: Clip) -> Bool {
        switch clip.kind {
        case .text: return true
        case .image: return image(for: clip) != nil
        case .files:
            let urls = fileURLs(for: clip)
            return !urls.isEmpty && urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    func copy(_ clip: Clip) -> Bool {
        let image = clip.kind == .image ? image(for: clip) : nil
        let urls = clip.kind == .files ? fileURLs(for: clip) : []
        guard canRestore(clip) else { return false }
        pasteboard.clearContents()
        let copied: Bool
        switch clip.kind {
        case .text:
            copied = pasteboard.setString(clip.text, forType: .string)
        case .image:
            copied = image.map { pasteboard.writeObjects([$0]) } ?? false
            if copied, clip.imageName?.hasSuffix(".gif") == true,
               let imageName = clip.imageName,
               let data = try? Data(contentsOf: directory.appendingPathComponent(imageName)) {
                pasteboard.setData(data, forType: NSPasteboard.PasteboardType(UTType.gif.identifier))
            }
        case .files:
            copied = pasteboard.writeObjects(urls.map { $0 as NSURL })
        }
        lastChangeCount = pasteboard.changeCount
        if copied { promote(clip) }
        return copied
    }

    func togglePin(_ clip: Clip) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        clips[index].isPinned.toggle()
        pruneAndSave()
    }

    func delete(_ clip: Clip) {
        remove([clip])
        save()
    }

    func clearUnpinned() {
        remove(clips.filter { !$0.isPinned })
        save()
    }

    func captureNow() {
        if Date().timeIntervalSince(lastPruneDate) > 3600 { pruneAndSave() }
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard !isPaused, !hasPrivateType() else { return }

        let fileURLs = (pasteboard.readObjects(forClasses: [NSURL.self],
                             options: [.urlReadingFileURLsOnly: true]) ?? [])
            .compactMap { $0 as? URL }
            .filter { $0.isFileURL }
        if !fileURLs.isEmpty {
            insert(kind: .files, text: fileURLs.map(\.lastPathComponent).joined(separator: ", "),
                   imageData: nil, filePaths: fileURLs.map(\.path))
        } else if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.gif.identifier)),
                  data.count <= 10_000_000, NSImage(data: data) != nil {
            insert(kind: .image, text: "Image", imageData: data, filePaths: nil, imageExtension: "gif")
        } else if let text = pasteboard.string(forType: .string), !text.isEmpty,
           text.utf8.count <= 1_000_000 {
            insert(kind: .text, text: text, imageData: nil, filePaths: nil)
        } else if let image = NSImage(pasteboard: pasteboard),
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let data = bitmap.representation(using: .png, properties: [:]),
                  data.count <= 10_000_000 {
            insert(kind: .image, text: "Image", imageData: data, filePaths: nil)
        }
    }

    private func hasPrivateType() -> Bool {
        let privateTypes = [
            "org.nspasteboard.ConcealedType",
            "org.nspasteboard.TransientType",
            "org.nspasteboard.AutoGeneratedType",
        ]
        return privateTypes.contains { pasteboard.types?.contains(NSPasteboard.PasteboardType($0)) == true }
    }

    private func insert(kind: ClipKind, text: String, imageData: Data?, filePaths: [String]?,
                        imageExtension: String = "png") {
        let data = imageData ?? Data((filePaths ?? [text]).joined(separator: "\u{0}").utf8)
        let fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let existing = clips.first(where: { $0.fingerprint == fingerprint && $0.kind == kind }) {
            promote(existing)
            return
        }

        let id = UUID()
        let imageName = imageData.map { _ in "\(id.uuidString).\(imageExtension)" }
        if let imageData, let imageName {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try imageData.write(to: directory.appendingPathComponent(imageName), options: .atomic)
            } catch { return }
        }

        clips.insert(Clip(id: id, kind: kind, text: text, imageName: imageName,
                          filePaths: filePaths,
                          fingerprint: fingerprint, createdAt: .now, isPinned: false), at: 0)
        prune()
        save()
    }

    private func promote(_ clip: Clip) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        var refreshed = clips.remove(at: index)
        refreshed.createdAt = .now
        clips.insert(refreshed, at: 0)
        prune()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("history.json")),
              let state = try? JSONDecoder().decode(SavedState.self, from: data) else { return }
        isLoading = true
        clips = state.clips.filter { $0.imageName == nil ||
            FileManager.default.fileExists(atPath: directory.appendingPathComponent($0.imageName!).path) }
        isPaused = state.isPaused
        retentionDays = state.retentionDays ?? 30
        maxItems = state.maxItems ?? 200
        isLoading = false
        pruneAndSave()
    }

    private func pruneAndSave() {
        prune()
        save()
    }

    private func prune() {
        lastPruneDate = .now
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now)
        let expired = clips.filter { !$0.isPinned && retentionDays > 0 && $0.createdAt < (cutoff ?? .distantPast) }
        remove(expired)
        if maxItems > 0 {
            let overflow = Array(clips.filter { !$0.isPinned }.dropFirst(maxItems))
            remove(overflow)
        }
    }

    private func remove(_ items: [Clip]) {
        let ids = Set(items.map(\.id))
        clips.removeAll { ids.contains($0.id) }
        for clip in items {
            if let imageName = clip.imageName {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(imageName))
            }
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(SavedState(clips: clips, isPaused: isPaused,
                                                           retentionDays: retentionDays, maxItems: maxItems))
            try data.write(to: directory.appendingPathComponent("history.json"), options: .atomic)
        } catch {
            NSLog("WooHooDoo could not save history: %@", error.localizedDescription)
        }
    }
}
