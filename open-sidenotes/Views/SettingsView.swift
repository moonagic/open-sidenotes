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

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var tintColor: Color

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "E0E0E0"))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(tintColor)
                    .frame(width: progress(in: geometry.size.width), height: 4)

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .frame(width: 16, height: 16)
                    .offset(x: progress(in: geometry.size.width) - 8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                updateValue(in: geometry.size.width, at: gesture.location.x)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .frame(height: 16)
        }
        .frame(height: 16)
    }

    private func progress(in width: CGFloat) -> CGFloat {
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(normalizedValue) * width
    }

    private func updateValue(in width: CGFloat, at location: CGFloat) {
        let normalizedValue = max(0, min(1, location / width))
        let newValue = range.lowerBound + normalizedValue * (range.upperBound - range.lowerBound)
        let steppedValue = round(newValue / step) * step
        value = max(range.lowerBound, min(range.upperBound, steppedValue))
    }
}

struct SettingsView: View {
    @State private var currentPath: String
    @State private var showReloadAlert = false
    @State private var showUpdateAlert = false
    @ObservedObject private var shortcutSettings = ShortcutSettings.shared
    @ObservedObject private var updateService = GitHubUpdateService.shared

    let onPathChanged: () -> Void

    init(onPathChanged: @escaping () -> Void) {
        self.onPathChanged = onPathChanged
        _currentPath = State(initialValue: FileStorageService.shared.storageDirectory.path)
    }

    var body: some View {
        VStack(spacing: 0) {
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
                Text("Window Behavior")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "666666"))

                Toggle(isOn: $shortcutSettings.autoHideOnMouseExit) {
                    Text("Auto-hide when mouse exits")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "666666"))
                }
                .toggleStyle(CustomToggleStyle(tintColor: Color(hex: "7C9885")))

                if shortcutSettings.autoHideOnMouseExit {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Hide Delay")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "666666"))
                            Spacer()
                            Text(String(format: "%.1f s", shortcutSettings.hideDelay))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "7C9885"))
                        }

                        CustomSlider(
                            value: $shortcutSettings.hideDelay,
                            range: 0.0...3.0,
                            step: 0.1,
                            tintColor: Color(hex: "7C9885")
                        )
                    }
                }

                Text("Control whether the window hides automatically when mouse leaves")
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

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Software Update")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "666666"))

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Version: v\(updateService.currentVersion)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "666666"))

                        if let latest = updateService.latestVersion {
                            if updateService.hasNewVersion() {
                                Text("Latest Version: v\(latest) (New available)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "7C9885"))
                            } else {
                                Text("Up to date")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "999999"))
                            }
                        }

                        if let error = updateService.checkError {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "E57373"))
                        }
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            await updateService.checkForUpdates(silent: false)
                        }
                    }) {
                        HStack(spacing: 6) {
                            if updateService.isChecking {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                            }
                            Text(updateService.isChecking ? "Checking..." : "Check for Updates")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "7C9885"))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(updateService.isChecking)
                }

                Text("Automatic update check frequency: Daily")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "999999"))
            }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            Divider()

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
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white)
        }
        .frame(width: 450, height: shortcutSettings.autoHideOnMouseExit ? 750 : 700)
        .background(Color.white)
        .animation(.easeInOut(duration: 0.3), value: shortcutSettings.autoHideOnMouseExit)
        .alert("Reload Required", isPresented: $showReloadAlert) {
            Button("Reload Now", role: .none) {
                onPathChanged()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Storage location changed. Reload notes to see files from the new location?")
        }
        .sheet(isPresented: $updateService.showUpdateAlert) {
            UpdateAlertView(updateService: updateService)
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
