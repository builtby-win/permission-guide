import XCTest
@testable import PermissionGuide

final class PermissionGuideTests: XCTestCase {
    func testKindRawValuesMatchCABI() {
        XCTAssertEqual(PermissionKind.accessibility.rawValue, 0)
        XCTAssertEqual(PermissionKind.screenRecording.rawValue, 1)
        XCTAssertEqual(PermissionKind.inputMonitoring.rawValue, 2)
    }

    func testPaneURLs() {
        XCTAssertEqual(PermissionKind.accessibility.paneURL.absoluteString,
                       "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        XCTAssertTrue(PermissionKind.screenRecording.paneURL.absoluteString.hasSuffix("Privacy_ScreenCapture"))
        XCTAssertTrue(PermissionKind.inputMonitoring.paneURL.absoluteString.hasSuffix("Privacy_ListenEvent"))
    }

    func testAppNameExplicitWins() {
        XCTAssertEqual(resolveAppName("Foo", appURL: URL(fileURLWithPath: "/nope/Bar.app")), "Foo")
    }

    func testAppNameEmptyExplicitFallsBackToFileName() {
        XCTAssertEqual(resolveAppName("", appURL: URL(fileURLWithPath: "/nope/Bar.app")), "Bar")
    }

    func testAppNameFromBundleInfo() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pg-\(UUID().uuidString)/Baz.app/Contents")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent().deletingLastPathComponent()) }
        let plist: [String: Any] = ["CFBundleName": "BazName", "CFBundleIdentifier": "x.baz"]
        try (plist as NSDictionary).write(to: dir.appendingPathComponent("Info.plist"))
        let app = dir.deletingLastPathComponent()
        XCTAssertEqual(resolveAppName(nil, appURL: app), "BazName")
    }

    func testStringsPickFirstSupportedLanguageElseEnglish() {
        XCTAssertEqual(Strings.string(.doneTitle, languages: ["xx-YY", "de-DE", "ja"]), "Fertig")
        XCTAssertEqual(Strings.string(.doneTitle, languages: ["zh-Hans-CN"]), "已完成")
        XCTAssertEqual(Strings.string(.doneTitle, languages: ["xx"]), "All set")
    }
}
