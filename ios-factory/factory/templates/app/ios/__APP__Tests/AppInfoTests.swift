import Testing
@testable import {{APP}}

struct AppInfoTests {
    @Test func versionShowsMarketingVersionAndBuild() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2", "CFBundleVersion": "34"]
        #expect(AppInfo.versionText(info) == "1.2 (34)")
    }

    @Test func versionCopesWithMissingKeys() {
        #expect(AppInfo.versionText([:]) == "? (?)")
    }
}
