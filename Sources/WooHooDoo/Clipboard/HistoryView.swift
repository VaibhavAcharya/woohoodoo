import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var store: ClipboardStore
    @FocusState private var searchFocused: Bool

    init(controller: AppController) {
        self.controller = controller
        store = controller.store
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if controller.showSettings {
                SettingsView(controller: controller)
            } else {
                HStack(spacing: 0) {
                    sidebar
                    Divider()
                    PreviewPane(controller: controller)
                }
            }
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: controller.presentationCount) { _, _ in
            DispatchQueue.main.async { searchFocused = true }
        }
        .onChange(of: controller.query) { _, _ in
            controller.selectedIndex = 0
        }
        .confirmationDialog("Clear clipboard history?", isPresented: $controller.showClearConfirmation) {
            Button("Clear unpinned items", role: .destructive) { store.clearUnpinned() }
        } message: {
            Text("Pinned items will stay in your history.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if let icon = AppIcon.image {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 9))
            }
            Text("WooHooDoo")
                .font(.system(size: 13, weight: .semibold))
            if controller.showSettings {
                Text("Settings")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                searchField
                    .padding(.leading, 6)
            }
            if store.isPaused {
                Label("Capture paused", systemImage: "pause.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.1), in: Capsule())
            }
            Button {
                controller.showSettings.toggle()
                if !controller.showSettings { searchFocused = true }
            } label: {
                Image(systemName: controller.showSettings ? "xmark" : "gearshape")
                    .frame(width: 22, height: 22)
            }
            .modifier(GlassControlStyle())
            .foregroundStyle(.primary)
            .accessibilityLabel(controller.showSettings ? "Close settings" : "Settings")
            Menu {
                Button(store.isPaused ? "Resume capturing" : "Pause capturing") {
                    store.isPaused.toggle()
                }
                Button("Clear unpinned history") { controller.showClearConfirmation = true }
                Divider()
                Button("Quit WooHooDoo") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 22, height: 22)
                    .modifier(GlassSurface())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More options")
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(.regularMaterial)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $controller.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .font(.system(size: 13))
            if !controller.query.isEmpty {
                Button {
                    controller.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .modifier(GlassSurface())
    }

    private var sidebar: some View {
        let clips = controller.filteredClips
        let selectedID = clips.indices.contains(controller.selectedIndex)
            ? clips[controller.selectedIndex].id : clips.last?.id
        return VStack(alignment: .leading, spacing: 0) {
            Picker("Filter", selection: $controller.filter) {
                ForEach(ClipFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.top, 14)

            HStack {
                Text("HISTORY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(clips.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if clips.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(clips) { clip in
                                ClipRow(clip: clip, selected: selectedID == clip.id,
                                        store: store, onSelect: { controller.select(clip) },
                                        onPaste: { controller.paste(clip) })
                                    .id(clip.id)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 12)
                    }
                    .onChange(of: controller.selectedIndex) { _, index in
                        let clips = controller.filteredClips
                        if clips.indices.contains(index) {
                            withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(clips[index].id) }
                        }
                    }
                }
            }
        }
        .frame(width: 306)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: controller.query.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 27, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text(controller.query.isEmpty ? "Nothing here yet" : "No matching clips")
                .font(.system(size: 13, weight: .medium))
            Text(controller.query.isEmpty ? "Copy text, an image, or a file." : "Try a different search or filter.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            if controller.showSettings {
                Text("esc  Close settings")
            } else {
                Text("↑ ↓  Navigate")
                Text("esc  Close")
            }
            Spacer()
            Text("⌘⇧V")
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .frame(height: 34)
        .background(.regularMaterial)
    }
}

private struct ClipRow: View {
    let clip: Clip
    let selected: Bool
    let store: ClipboardStore
    let onSelect: () -> Void
    let onPaste: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            icon
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(kindLabel)
                    Text("·")
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(relativeTime(at: context.date))
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.indigo)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 61)
        .background(selected ? Color.accentColor.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(
            selected ? Color.accentColor.opacity(0.3) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onPaste)
        .onTapGesture(perform: onSelect)
    }

    private var icon: some View {
        Group {
            if clip.kind == .image, let image = store.image(for: clip) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: clip.kind == .files ? "doc.fill" :
                        clip.text.contains("\n") ? "curlybraces" : "text.alignleft")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(clip.kind == .files ? .blue : .secondary)
            }
        }
        .frame(width: 38, height: 38)
        .background(Color(nsColor: .windowBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        switch clip.kind {
        case .text: return clip.text.replacingOccurrences(of: "\n", with: " ")
        case .image: return "Image"
        case .files: return clip.filePaths?.count == 1
            ? (clip.filePaths?.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File")
            : "\(clip.filePaths?.count ?? 0) files"
        }
    }

    private var kindLabel: String {
        switch clip.kind {
        case .text: return clip.text.contains("\n") ? "Code / text" : "Text"
        case .image: return "Image"
        case .files: return "File"
        }
    }

    private func relativeTime(at date: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSince(clip.createdAt) / 60))
        if minutes == 0 { return "now" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr" }
        let days = hours / 24
        return days == 1 ? "1 day" : "\(days) days"
    }
}
