import Foundation
import AppKit

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let assets: [Asset]
    let publishedAt: String

    struct Asset: Codable {
        let name: String
        let browserDownloadUrl: String
        let size: Int

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
            case size
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case assets
        case publishedAt = "published_at"
    }
}

@MainActor
class GitHubUpdateService: ObservableObject {
    static let shared = GitHubUpdateService()

    @Published var latestVersion: String?
    @Published var currentVersion: String
    @Published var downloadURL: URL?
    @Published var releaseNotes: String?
    @Published var releaseDate: Date?
    @Published var fileSize: Int64?
    @Published var isChecking = false
    @Published var checkError: String?
    @Published var showUpdateAlert = false

    private let repoOwner = "mlhiter"
    private let repoName = "open-sidenotes"
    private let lastCheckKey = "LastUpdateCheckDate"

    private init() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            currentVersion = version
        } else {
            currentVersion = "1.0.0"
        }
    }

    func checkForUpdates(silent: Bool = false) async {
        guard !isChecking else { return }

        isChecking = true
        checkError = nil

        defer {
            isChecking = false
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
        }

        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            checkError = "Invalid URL"
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                checkError = "Invalid response"
                return
            }

            guard httpResponse.statusCode == 200 else {
                checkError = "Server returned error: \(httpResponse.statusCode)"
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

            latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            releaseNotes = release.body

            let dateFormatter = ISO8601DateFormatter()
            releaseDate = dateFormatter.date(from: release.publishedAt)

            #if arch(arm64)
            let assetName = "open-sidenotes-arm64.dmg"
            #else
            let assetName = "open-sidenotes-x86_64.dmg"
            #endif

            if let asset = release.assets.first(where: { $0.name == assetName }) {
                downloadURL = URL(string: asset.browserDownloadUrl)
                fileSize = Int64(asset.size)
            }

            if hasNewVersion() && !silent {
                showUpdateAlert = true
            }

        } catch {
            checkError = "Check update failed: \(error.localizedDescription)"
        }
    }

    func hasNewVersion() -> Bool {
        guard let latest = latestVersion else { return false }
        return compareVersions(latest, currentVersion) == .orderedDescending
    }

    private func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let components1 = v1.split(separator: ".").compactMap { Int($0) }
        let components2 = v2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(components1.count, components2.count)

        for i in 0..<maxLength {
            let num1 = i < components1.count ? components1[i] : 0
            let num2 = i < components2.count ? components2[i] : 0

            if num1 > num2 {
                return .orderedDescending
            } else if num1 < num2 {
                return .orderedAscending
            }
        }

        return .orderedSame
    }

    func downloadUpdate() {
        guard let url = downloadURL else { return }
        NSWorkspace.shared.open(url)
    }

    func formattedFileSize() -> String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    func formattedReleaseDate() -> String? {
        guard let date = releaseDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    func shouldAutoCheck() -> Bool {
        guard let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date else {
            return true
        }
        let daysSinceLastCheck = Calendar.current.dateComponents([.day], from: lastCheck, to: Date()).day ?? 0
        return daysSinceLastCheck >= 1
    }
}
