import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPath: String
    @State private var showReloadAlert = false

    let onPathChanged: () -> Void

    init(onPathChanged: @escaping () -> Void) {
        self.onPathChanged = onPathChanged
        _currentPath = State(initialValue: FileStorageService.shared.storageDirectory.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "2C2C2C"))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Storage Location")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "666666"))

                Text(currentPath)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "888888"))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "F5F5F5"))
                    .cornerRadius(6)

                Button(action: selectFolder) {
                    Text("Choose Folder")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "7C9885"))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Text("Notes will be stored as Markdown (.md) files")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "999999"))
            }

            Spacer()

            HStack {
                Button(action: resetToDefault) {
                    Text("Reset to Default")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "888888"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(hex: "7C9885"))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 340, height: 280)
        .background(Color.white)
        .alert("Reload Required", isPresented: $showReloadAlert) {
            Button("Reload Now", role: .none) {
                onPathChanged()
                dismiss()
            }
            Button("Later", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Storage location changed. Reload notes to see files from the new location?")
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select a folder to store your notes"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            currentPath = url.path
            FileStorageService.shared.storageDirectory = url
            showReloadAlert = true
        }
    }

    private func resetToDefault() {
        let defaultPath = Constants.defaultNotesDirectory()
        currentPath = defaultPath.path
        FileStorageService.shared.storageDirectory = defaultPath
        showReloadAlert = true
    }
}
