import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var store: ClipboardStore

    init(controller: AppController) {
        self.controller = controller
        store = controller.store
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Clipboard settings")
                        .font(.system(size: 21, weight: .semibold))
                    Text("Choose how long history stays on this Mac.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    settingRow(title: "Keep unpinned clips",
                               detail: "Older items are removed automatically.") {
                        Picker("Keep unpinned clips", selection: $store.retentionDays) {
                            Text("1 day").tag(1)
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("Forever").tag(0)
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                    Divider().padding(.leading, 18)
                    settingRow(title: "Maximum unpinned clips",
                               detail: "The oldest items go first when the limit is reached.") {
                        Picker("Maximum unpinned clips", selection: $store.maxItems) {
                            Text("50 clips").tag(50)
                            Text("200 clips").tag(200)
                            Text("500 clips").tag(500)
                            Text("Unlimited").tag(0)
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 12))

                Label("Pinned clips stay until you delete them and do not count toward the limit.",
                      systemImage: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Capture and storage")
                        .font(.system(size: 14, weight: .semibold))
                    Toggle("Launch WooHooDoo at login", isOn: Binding(
                        get: { controller.launchAtLoginEnabled },
                        set: { controller.setLaunchAtLogin($0) }
                    ))
                    .font(.system(size: 12))
                    if let error = controller.loginItemError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    Toggle("Capture new clips", isOn: Binding(
                        get: { !store.isPaused },
                        set: { store.isPaused = !$0 }
                    ))
                    .font(.system(size: 12))
                    Text("Text and copied images are saved locally. Files are saved as references to their original locations; previews stop working if those files move or are deleted.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Clear unpinned history") {
                        controller.showClearConfirmation = true
                    }
                    .font(.system(size: 12))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: 720)
            .padding(22)
            .frame(maxWidth: .infinity)
        }
    }

    private func settingRow<Control: View>(title: String, detail: String,
                                           @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 18)
        .frame(height: 62)
    }
}
