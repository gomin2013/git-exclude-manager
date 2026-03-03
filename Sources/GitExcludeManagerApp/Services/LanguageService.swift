import Foundation

/// Service for managing app language preferences with runtime bundle switching.
/// Use `LanguageService.shared.localized(_:)` (or the `L()` helper) for all string translations.
@MainActor
class LanguageService: ObservableObject {

    // MARK: - Language Enum

    enum Language: String, CaseIterable, Identifiable {
        case english = "en"
        case thai = "th"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .english: return "English"
            case .thai:    return "ไทย"
            }
        }

        var flag: String {
            switch self {
            case .english: return "🇺🇸"
            case .thai:    return "🇹🇭"
            }
        }
    }

    // MARK: - Singleton

    static let shared = LanguageService()

    // MARK: - Private Constants

    private static let preferenceKey = "app.language"

    // MARK: - Published State

    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.preferenceKey)
            reloadBundle()
        }
    }

    // MARK: - Private State

    private var bundle: Bundle = .main

    // MARK: - Init

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.preferenceKey)
        if let saved, let lang = Language(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            // Fall back to system language
            let preferred = NSLocale.preferredLanguages.first ?? "en"
            self.currentLanguage = preferred.hasPrefix("th") ? .thai : .english
        }
        reloadBundle()
    }

    // MARK: - Public Interface

    /// Returns the localized string for `key` using the currently selected language bundle.
    func localized(_ key: String, comment: String = "") -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    // MARK: - Private Methods

    private func reloadBundle() {
        // The .app ships the .lproj folders in Contents/Resources. Under `swift test` / `swift run` there is no
        // app bundle, so read SwiftPM's resource bundle instead (never touched from a .app: Bundle.module
        // traps if its bundle is missing).
        let resources = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main : Bundle.module
        guard
            let path = resources.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
            let languageBundle = Bundle(path: path)
        else {
            bundle = .main
            return
        }
        bundle = languageBundle
    }
}
