import SwiftUI

/// Settings dropdown button — Language / Appearance / AI API
/// Matches .prototype settingsDropdown
struct SettingsDropdownView: View {
    @ObservedObject var languageService: LanguageService
    @Binding var colorScheme: ColorSchemePreference
    var onAbout: () -> Void = {}

    // Observe for re-render on language switch
    @EnvironmentObject private var envLanguage: LanguageService

    enum ColorSchemePreference: String, CaseIterable {
        case system, light, dark

        @MainActor var label: String {
            switch self {
            case .system: return localized("theme.system")
            case .light:  return localized("theme.light")
            case .dark:   return localized("theme.dark")
            }
        }

        var icon: String {
            switch self {
            case .system: return "💻"
            case .light:  return "☀️"
            case .dark:   return "🌙"
            }
        }
    }

    var body: some View {
        Menu {
            // MARK: - Language
            // Inline pickers: native menu checkmarks + VoiceOver "selected" state (was a hand-drawn checkmark image)
            Picker(localized("menu.language"), selection: $languageService.currentLanguage) {
                ForEach(LanguageService.Language.allCases, id: \.self) { lang in
                    Text(lang.flag + " " + lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.inline)

            Divider()

            // MARK: - Appearance
            Picker(localized("menu.appearance"), selection: $colorScheme) {
                ForEach(ColorSchemePreference.allCases, id: \.self) { pref in
                    Text(pref.icon + " " + pref.label).tag(pref)
                }
            }
            .pickerStyle(.inline)

            Divider()

            // MARK: - About (Help lives in the right-column panel)
            Button(action: onAbout) {
                Label(localized("menu.about"), systemImage: "info.circle")
            }
        } label: {
            Label(localized("btn.settings"), systemImage: "gearshape")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(localized("btn.settings"))
    }
}

struct SettingsDropdownView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsDropdownView(
            languageService: LanguageService.shared,
            colorScheme: .constant(.system)
        )
        .environmentObject(LanguageService.shared)
        .padding()
    }
}
