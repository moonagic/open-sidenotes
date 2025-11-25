import SwiftUI

struct UpdateAlertView: View {
    @ObservedObject var updateService: GitHubUpdateService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "7C9885"))

                VStack(alignment: .leading, spacing: 4) {
                    Text("New Version Available")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "333333"))

                    if let latest = updateService.latestVersion {
                        Text("v\(latest)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "666666"))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Version")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "999999"))
                        Text("v\(updateService.currentVersion)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "666666"))
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "CCCCCC"))

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Latest Version")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "999999"))
                        if let latest = updateService.latestVersion {
                            Text("v\(latest)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "7C9885"))
                        }
                    }
                }

                if let date = updateService.formattedReleaseDate() {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "999999"))
                        Text("Released: \(date)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "999999"))
                    }
                }

                if let size = updateService.formattedFileSize() {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "999999"))
                        Text("File Size: \(size)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "999999"))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(hex: "F8F9FA"))

            if let notes = updateService.releaseNotes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Release Notes")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "666666"))

                    ScrollView {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "666666"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                    .padding(12)
                    .background(Color(hex: "F5F5F5"))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }

            Divider()

            HStack(spacing: 12) {
                Button(action: {
                    dismiss()
                }) {
                    Text("Remind Me Later")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "666666"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    updateService.downloadUpdate()
                    dismiss()
                }) {
                    Text("Download Now")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "7C9885"))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 480)
        .background(Color.white)
    }
}

#Preview {
    UpdateAlertView(updateService: GitHubUpdateService.shared)
}
