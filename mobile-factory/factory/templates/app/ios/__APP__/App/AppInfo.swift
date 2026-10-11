import Foundation

/// Facts about the running build, for Settings and support emails.
enum AppInfo {
    /// "0.1 (12)": marketing version and build number.
    static var version: String { versionText(Bundle.main.infoDictionary ?? [:]) }

    static func versionText(_ info: [String: Any]) -> String {
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
