import SwiftUI

/// Appearance panel: Light / Dark / System, solid accents (shared `AccentPicker`) and gradient themes, in that
/// order; a theme also sets its paired accent. Reads the same @AppStorage keys as PatternsView.
struct AppearancePanel: View {
    @AppStorage("ui.accent") private var accent = AccentChoice.system
    @AppStorage("ui.gradient") private var theme = GradientTheme.none
    @AppStorage("ui.appearance") private var appearance = AppearanceChoice.system

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localized("menu.appearance")).font(.app(13, .semibold))
                    Picker(localized("menu.appearance"), selection: $appearance) {
                        ForEach(AppearanceChoice.allCases) { option in
                            Label(localized("theme." + option.rawValue), systemImage: option.icon).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(16)
                Divider()
                AccentPicker(choice: $accent)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text(localized("theme.gradient")).font(.app(13, .semibold))
                    let themes = Array(GradientTheme.allCases.dropFirst())
                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                        ForEach([0, 4], id: \.self) { start in
                            GridRow { ForEach(themes[start..<start + 4]) { swatch($0) } }
                        }
                    }
                    Button(localized("theme.noGradient")) { theme = .none }.disabled(theme == .none)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func swatch(_ option: GradientTheme) -> some View {
        Button {
            theme = option
            accent = option.accent
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: option.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 36)
                .overlay {
                    if option == theme { RoundedRectangle(cornerRadius: 8).strokeBorder(.primary, lineWidth: 2) }
                }
        }
        .buttonStyle(.plain)
        .help(option.name)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(option == theme ? .isSelected : [])
    }
}

/// Language panel: search by native, English or translated name (or code), then click to switch — no restart.
struct LanguagePanel: View {
    @EnvironmentObject private var languageService: LanguageService
    @State private var query = ""

    var body: some View {
        let current = languageService.currentLanguage
        let matches = LanguageService.Language.allCases.filter { $0.matches(query, uiLanguage: current) }
        VStack(alignment: .leading, spacing: 0) {
            TextField(localized("language.search"), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(16)
            if matches.isEmpty {
                Text(localized("language.noResults", args: query))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                Spacer()
            } else {
                List(matches) { option in
                    LanguageRow(option: option, uiLanguage: current)
                        .onTapGesture { languageService.currentLanguage = option }
                        .accessibilityAction { languageService.currentLanguage = option }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

/// One language: flag, its own name, and its name in the current UI language ("ญี่ปุ่น" under 日本語 when in Thai).
private struct LanguageRow: View {
    let option: LanguageService.Language
    let uiLanguage: LanguageService.Language

    var body: some View {
        let isCurrent = option == uiLanguage
        let translated = option.name(in: uiLanguage)
        HStack(spacing: 10) {
            Text(option.flag).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(option.nativeName).fontWeight(isCurrent ? .semibold : .regular)
                if translated != option.nativeName {
                    Text(translated).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if isCurrent { Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityHidden(true) }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}

/// About panel (Settings is split into Language / About for now).
struct AboutPanel: View {
    var body: some View {
        ScrollView { AboutView() }
    }
}
