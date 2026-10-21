import XCTest
@testable import GitExcludeManagerApp

/// en and th must have identical keys, every key the sources use must exist, and no UI literal may bypass `localized`.
/// Ported from hosts-manager's `LocalizationTests` after the v1.1 accent / gradient pickers shipped English-only here.
@MainActor
final class LocalizationTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let appSources = root.appendingPathComponent("Sources/GitExcludeManagerApp")

    private func keys(_ lang: String) throws -> Set<String> {
        let url = Self.appSources.appendingPathComponent("Resources/\(lang).lproj/Localizable.strings")
        let dict = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], "\(lang) strings unreadable")
        return Set(dict.keys)
    }

    private func sourceLines() throws -> [(file: String, line: String)] {
        let files = try XCTUnwrap(FileManager.default.enumerator(at: Self.appSources, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        return try files.flatMap { url in
            try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n").map { (url.lastPathComponent, String($0)) }
        }
    }

    func testEnglishAndThaiHaveTheSameKeys() throws {
        let english = try keys("en"), thai = try keys("th")
        XCTAssertEqual(english.subtracting(thai).sorted(), [], "missing in th")
        XCTAssertEqual(thai.subtracting(english).sorted(), [], "missing in en")
    }

    /// Every key-shaped literal on a `localized(…)` line exists — a missing one shows the raw key in the UI.
    func testSourceKeysExist() throws {
        var used = Set<String>()
        for (_, line) in try sourceLines() where line.contains("localized(") {
            let text = line.replacing(/system(?:Name|Image): "[^"]*"/, with: "")  // SF Symbol names
            used.formUnion(text.matches(of: /"([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+)"/).map { String($0.output.1) })
        }
        XCTAssertGreaterThan(used.count, 100)
        XCTAssertEqual(used.subtracting(try keys("en")).sorted(), [])
    }

    /// Keys built at run time from enum cases.
    func testDynamicThemeKeysExist() throws {
        let known = try keys("en")
        let dynamic = AccentChoice.allCases.map { "accent." + $0.rawValue }
            + GradientTheme.allCases.map { "gradient." + $0.rawValue }
            + AppearanceChoice.allCases.map { "theme." + $0.rawValue }
        XCTAssertEqual(Set(dynamic).subtracting(known).sorted(), [])
    }

    /// `Text("Accent Colour")` stays English when the app is in Thai. Only interpolation-only literals
    /// (`"\(count)"`) and the product name may skip `localized`.
    func testNoHardcodedUILiterals() throws {
        let allowed: Set<String> = ["Git Exclude Manager"]
        var offenders: [String] = []
        for (file, line) in try sourceLines() {
            for match in line.matches(of: /(?:Text|Button|Label|Toggle|\.help|\.accessibilityLabel)\("([^"]*)"/) {
                let literal = String(match.output.1)
                let visible = literal.replacing(/\\\([^)]*\)/, with: "")
                if visible.contains(/[A-Za-z]{2}/), !allowed.contains(literal) {
                    offenders.append("\(file): \(literal)")
                }
            }
        }
        XCTAssertEqual(offenders, [])
    }
}
