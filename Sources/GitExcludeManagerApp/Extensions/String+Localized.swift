import Foundation

/// Convenience free function for localized strings.
/// Reads from the runtime bundle managed by `LanguageService.shared`
/// so language switching works instantly without restarting the app.
///
/// Usage:
/// ```swift
/// Text(localized("btn.add"))
/// Text(localized("status.patternsCount", args: count, enabledCount))
/// ```
@MainActor
func localized(_ key: String, comment: String = "") -> String {
    LanguageService.shared.localized(key, comment: comment)
}

/// Format variant — supports `String(format:)` style substitution.
@MainActor
func localized(_ key: String, comment: String = "", args: CVarArg...) -> String {
    let template = LanguageService.shared.localized(key, comment: comment)
    return String(format: template, arguments: args)
}
