import AppKit
import AVKit
import QuickLookUI
import SwiftUI
import UniformTypeIdentifiers

struct PreviewPane: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var store: ClipboardStore

    init(controller: AppController) {
        self.controller = controller
        store = controller.store
    }

    var body: some View {
        Group {
            if let clip = controller.selectedClip {
                VStack(alignment: .leading, spacing: 0) {
                    header(for: clip)
                    preview(for: clip)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.primary.opacity(0.025),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.primary.opacity(0.08)))
                        .padding(.horizontal, 18)
                    actions(for: clip)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 33, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Text("Select a clip to preview")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func header(for clip: Clip) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(kindLabel(for: clip).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Text(title(for: clip))
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(clip.createdAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if clip.isPinned {
                Label("Pinned", systemImage: "pin.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.indigo.opacity(0.1), in: Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func preview(for clip: Clip) -> some View {
        switch clip.kind {
        case .text:
            ScrollView {
                Text(clip.text)
                    .font(.system(size: clip.text.contains("\n") ? 12 : 14,
                                  design: clip.text.contains("\n") ? .monospaced : .default))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
            .background(Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 10))
            .padding(10)
        case .image:
            if let image = store.image(for: clip) {
                ImagePreviewView(image: image)
                    .padding(20)
            } else {
                unavailable("Image unavailable")
            }
        case .files:
            filePreview(for: clip)
        }
    }

    private func filePreview(for clip: Clip) -> some View {
        let urls = store.fileURLs(for: clip)
        let index = min(controller.selectedFileIndex, max(urls.count - 1, 0))
        return VStack(spacing: 0) {
            if urls.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { fileIndex, url in
                            Button {
                                controller.selectedFileIndex = fileIndex
                            } label: {
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(fileIndex == index ? Color.accentColor.opacity(0.16) :
                                                Color(nsColor: .windowBackgroundColor), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                Divider()
            }
            if urls.indices.contains(index) {
                FilePreviewContent(url: urls[index])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                unavailable("File unavailable")
            }
            Divider()
            Text(urls.indices.contains(index) ? urls[index].path : "")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 32)
        }
    }

    private func actions(for clip: Clip) -> some View {
        HStack(spacing: 10) {
            Button {
                controller.togglePin(clip)
            } label: {
                actionLabel(nil,
                            symbol: clip.isPinned ? "pin.slash" : "pin", shortcut: "⌘.")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(clip.isPinned ? "Unpin" : "Pin")
            .help(clip.isPinned ? "Unpin (Command-Period)" : "Pin (Command-Period)")
            Button(role: .destructive) {
                controller.delete(clip)
            } label: {
                actionLabel(nil, symbol: "trash", shortcut: "⌘X")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Delete")
            .help("Delete (Command-X)")
            Spacer()
            Button { controller.copy(clip) } label: {
                actionLabel(nil, symbol: "doc.on.doc", shortcut: "⌘↩")
            }
                .buttonStyle(.bordered)
                .disabled(!store.canRestore(clip))
                .accessibilityLabel("Copy")
                .help("Copy (Command-Return)")
            Button { controller.paste(clip, keepingOpen: true) } label: {
                actionLabel("Paste and Keep Open", symbol: "arrow.turn.down.right", shortcut: "⌘⇧↩")
            }
                .buttonStyle(.bordered)
                .disabled(!store.canRestore(clip))
                .accessibilityLabel("Paste and keep the window open")
                .help("Paste and keep the window open (Command-Shift-Return)")
            Button { controller.paste(clip) } label: {
                actionLabel("Paste", symbol: "arrow.turn.down.right", shortcut: "↩")
            }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canRestore(clip))
                .help("Paste (Return). Press Command-Shift-Return to paste and keep the window open.")
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
    }

    private func actionLabel(_ title: String?, symbol: String, shortcut: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .frame(width: 14)
            if let title { Text(title) }
            Text(shortcut)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
        }
        .font(.system(size: 11, weight: .medium))
        .frame(height: 24)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func unavailable(_ title: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 28, weight: .ultraLight))
            Text(title).font(.system(size: 13, weight: .medium))
            Text("The original file may have moved or been deleted.")
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func title(for clip: Clip) -> String {
        switch clip.kind {
        case .text: return clip.text.components(separatedBy: .newlines).first ?? "Text"
        case .image: return "Copied image"
        case .files:
            let urls = store.fileURLs(for: clip)
            return urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files"
        }
    }

    private func kindLabel(for clip: Clip) -> String {
        switch clip.kind {
        case .text: return clip.text.contains("\n") ? "Code or text" : "Text"
        case .image: return "Image"
        case .files: return "File"
        }
    }
}

private struct FilePreviewContent: View {
    let url: URL

    var body: some View {
        Group {
            if !FileManager.default.fileExists(atPath: url.path) {
                placeholder
            } else if let text = readableText {
                ScrollView {
                    Text(text)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(20)
                }
                .background(Color(nsColor: .textBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 9))
                .padding(12)
            } else if url.pathExtension.lowercased() == "gif",
                      let image = NSImage(contentsOf: url) {
                ImagePreviewView(image: image)
                    .padding(20)
            } else if isVideo {
                VideoPreviewView(url: url)
                    .padding(8)
            } else {
                EmbeddedQuickLookView(url: url)
                    .padding(8)
            }
        }
    }

    private var readableText: String? {
        let extensions: Set<String> = [
            "txt", "md", "swift", "js", "jsx", "ts", "tsx", "py", "rb", "go",
            "rs", "java", "c", "h", "cpp", "css", "html", "xml", "json",
            "yaml", "yml", "toml", "sh", "sql", "log", "csv"
        ]
        guard extensions.contains(url.pathExtension.lowercased()),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 1_000_000 else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private var isVideo: Bool {
        let extensions: Set<String> = ["mov", "mp4", "m4v", "mpg", "mpeg", "3gp", "3g2"]
        return extensions.contains(url.pathExtension.lowercased()) ||
            (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?
                .conforms(to: .movie) == true
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.questionmark").font(.system(size: 28))
            Text("Original file unavailable")
            Text("WooHooDoo saves a reference to this file.")
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ImagePreviewView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> FlexibleImageView {
        let view = FlexibleImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.animates = true
        return view
    }

    func updateNSView(_ view: FlexibleImageView, context: Context) {
        view.image = image
    }
}

private final class FlexibleImageView: NSImageView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

private struct VideoPreviewView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeNSView(context: Context) -> FlexiblePlayerView {
        let view = FlexiblePlayerView()
        view.controlsStyle = .inline
        view.player = AVPlayer(url: url)
        return view
    }

    func updateNSView(_ view: FlexiblePlayerView, context: Context) {
        guard context.coordinator.url != url else { return }
        view.player?.pause()
        view.player = AVPlayer(url: url)
        context.coordinator.url = url
    }

    static func dismantleNSView(_ view: FlexiblePlayerView, coordinator: Coordinator) {
        view.player?.pause()
        view.player = nil
    }

    final class Coordinator {
        var url: URL

        init(url: URL) { self.url = url }
    }
}

private final class FlexiblePlayerView: AVPlayerView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

private struct EmbeddedQuickLookView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = false
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        view.previewItem = url as NSURL
    }

    static func dismantleNSView(_ view: QLPreviewView, coordinator: ()) {
        view.close()
    }
}
