import Foundation

/// Service for managing app language preferences
@MainActor
class LanguageService: ObservableObject {
    enum Language: String, CaseIterable {
        case english = "en"
        case thai = "th"

        var displayName: String {
            switch self {
            case .english:
                return "English"
            case .thai:
                return "ไทย"
            }
        }
    }

    private static let languagePreferenceKey = "app.language"

    @Published var currentLanguage: Language {
        didSet {
            saveLanguagePreference()
            applyLanguage()
        }
    }

    init() {
        self.currentLanguage = Self.loadLanguagePreference()
        applyLanguage()
    }

    private static func loadLanguagePreference() -> Language {
        let savedLanguage = UserDefaults.standard.string(forKey: languagePreferenceKey)
        if let saved = savedLanguage, let language = Language(rawValue: saved) {
            return language
        }
        // Fall back to system language preference
        return systemLanguagePreference()
    }

    private static func systemLanguagePreference() -> Language {
        let preferredLanguages = NSLocale.preferredLanguages
        for lang in preferredLanguages where lang.hasPrefix("th") {
            return .thai
        }
        return .english
    }

    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.languagePreferenceKey)
    }

    private func applyLanguage() {
        // Force reload of localized strings by changing the app's language
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
}
