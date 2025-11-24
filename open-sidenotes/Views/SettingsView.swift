import SwiftUI
import AppKit

struct CustomToggleStyle: ToggleStyle {
    var tintColor: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? tintColor : Color(hex: "E0E0E0"))
                .frame(width: 48, height: 28)
                .overlay(
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .padding(3)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

struct SettingsView: View {
    @State private var currentPath: String
    @State private var showReloadAlert = false
    @ObservedObject private var shortcutSettings = ShortcutSettings.shared

    let onPathChanged: () -> Void

    init(onPathChanged: @escaping () -> Void) {
        self.onPathChanged = onPathChanged
        _currentPath = State(initialValue: FileStorageService.shared.storageDirectory.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "666666"))

                Toggle(isOn: $shortcutSettings.showDockIcon) {
                    Text("Show Dock Icon")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "666666"))
                }
                .toggleStyle(CustomToggleStyle(tintColor: Color(hex: "7C9885")))

                Text("Requires app restart to take effect")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "999999"))
            }

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

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "666666"))

                HStack {
                    Text("Toggle Window")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "666666"))
                        .frame(width: 100, alignment: .leading)

                    ShortcutRecorderView(shortcut: $shortcutSettings.toggleWindowShortcut)
                }
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
            }
        }
        .padding(24)
        .frame(width: 450, height: 520)
        .background(Color.white)
        .alert("Reload Required", isPresented: $showReloadAlert) {
            Button("Reload Now", role: .none) {
                onPathChanged()
            }
            Button("Later", role: .cancel) {}
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

#Preview {
    SettingsView(onPathChanged: {})
}
