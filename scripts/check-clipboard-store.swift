import AppKit
import ImageIO
import UniformTypeIdentifiers

@main
@MainActor
struct ClipboardStoreChecks {
    static func main() throws {
        let checks = ClipboardStoreChecks()
        try checks.retentionRemovesOldUnpinnedClipsAndKeepsPins()
        checks.countLimitExcludesPinnedClips()
        checks.copyMovesClipToTopWithoutDuplicatingIt()
        try checks.capturesFileReferencesAndCopiesThemBack()
        try checks.preservesAnimatedGIFData()
        checks.skipsConcealedClipboardContent()
        print("Clipboard store checks passed")
    }

    func retentionRemovesOldUnpinnedClipsAndKeepsPins() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: .now)!
        let clips = [
            Clip(id: UUID(), kind: .text, text: "old", imageName: nil, filePaths: nil,
                 fingerprint: "old", createdAt: oldDate, isPinned: false),
            Clip(id: UUID(), kind: .text, text: "pinned", imageName: nil, filePaths: nil,
                 fingerprint: "pinned", createdAt: oldDate, isPinned: true),
            Clip(id: UUID(), kind: .text, text: "new", imageName: nil, filePaths: nil,
                 fingerprint: "new", createdAt: .now, isPinned: false),
        ]
        let state = SavedState(clips: clips, isPaused: false)
        try JSONEncoder().encode(state).write(to: directory.appendingPathComponent("history.json"))

        let store = ClipboardStore(pasteboard: temporaryPasteboard(),
                                   directory: directory, startsPolling: false)
        precondition(store.clips.map(\.text) == ["pinned", "new"])
        precondition(store.retentionDays == 30)
        precondition(store.maxItems == 200)
        store.togglePin(store.clips[0])
        precondition(store.clips.map(\.text) == ["new"])
    }

    func countLimitExcludesPinnedClips() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let pasteboard = temporaryPasteboard()
        let store = ClipboardStore(pasteboard: pasteboard, directory: directory, startsPolling: false)

        pasteboard.clearContents()
        pasteboard.setString("first", forType: .string)
        store.captureNow()
        precondition(store.clips.count == 1, "First text clip was not captured")
        store.togglePin(store.clips[0])

        pasteboard.clearContents()
        pasteboard.setString("second", forType: .string)
        store.captureNow()
        pasteboard.clearContents()
        pasteboard.setString("third", forType: .string)
        store.captureNow()
        store.maxItems = 1

        precondition(Set(store.clips.map(\.text)) == Set(["first", "third"]))
    }

    func capturesFileReferencesAndCopiesThemBack() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("sample.swift")
        try "let value = 1".write(to: file, atomically: true, encoding: .utf8)

        let pasteboard = temporaryPasteboard()
        let store = ClipboardStore(pasteboard: pasteboard, directory: directory, startsPolling: false)
        pasteboard.clearContents()
        precondition(pasteboard.writeObjects([file as NSURL]))
        store.captureNow()

        precondition(store.clips.first?.kind == .files)
        precondition(store.clips.first?.filePaths == [file.path])
        precondition(store.copy(store.clips[0]))
        let copied = pasteboard.readObjects(forClasses: [NSURL.self],
                          options: [.urlReadingFileURLsOnly: true])?.first as? URL
        precondition(copied?.path == file.path)
        try FileManager.default.removeItem(at: file)
        pasteboard.clearContents()
        pasteboard.setString("keep me", forType: .string)
        precondition(!store.copy(store.clips[0]))
        precondition(pasteboard.string(forType: .string) == "keep me")
    }

    func copyMovesClipToTopWithoutDuplicatingIt() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let pasteboard = temporaryPasteboard()
        let store = ClipboardStore(pasteboard: pasteboard, directory: directory, startsPolling: false)

        pasteboard.clearContents()
        pasteboard.setString("first", forType: .string)
        store.captureNow()
        pasteboard.clearContents()
        pasteboard.setString("second", forType: .string)
        store.captureNow()

        let first = store.clips[1]
        precondition(store.copy(first))
        store.captureNow()
        precondition(store.clips.map(\.text) == ["first", "second"])
        precondition(store.clips[0].id == first.id)
        precondition(store.clips.count == 2)
    }

    func preservesAnimatedGIFData() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let pasteboard = temporaryPasteboard()
        let store = ClipboardStore(pasteboard: pasteboard, directory: directory, startsPolling: false)
        let data = try animatedGIFData()
        let gifType = NSPasteboard.PasteboardType(UTType.gif.identifier)

        pasteboard.clearContents()
        precondition(pasteboard.setData(data, forType: gifType))
        store.captureNow()

        guard let clip = store.clips.first,
              let imageName = clip.imageName else { throw CocoaError(.fileReadUnknown) }
        precondition(clip.kind == .image)
        precondition(imageName.hasSuffix(".gif"))
        let storedData = try Data(contentsOf: directory.appendingPathComponent(imageName))
        precondition(storedData == data)
        precondition(store.copy(clip))
        precondition(pasteboard.data(forType: gifType) == data)
    }

    private func animatedGIFData() throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, 2, nil),
              let context = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let colors: [CGColor] = [NSColor.red.cgColor, NSColor.blue.cgColor]
        for color in colors {
            context.setFillColor(color)
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            guard let image = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
            let properties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary
            CGImageDestinationAddImage(destination, image, properties)
        }
        guard CGImageDestinationFinalize(destination),
              let source = CGImageSourceCreateWithData(data, nil),
              CGImageSourceGetCount(source) == 2 else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }

    func skipsConcealedClipboardContent() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let pasteboard = temporaryPasteboard()
        let store = ClipboardStore(pasteboard: pasteboard, directory: directory, startsPolling: false)

        pasteboard.declareTypes([.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")],
                                owner: nil)
        pasteboard.setString("secret", forType: .string)
        store.captureNow()

        precondition(store.clips.isEmpty)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("WooHooDooTests-\(UUID())")
    }

    private func temporaryPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("WooHooDooTests-\(UUID())"))
    }

    private struct SavedState: Codable {
        let clips: [Clip]
        let isPaused: Bool
    }
}
