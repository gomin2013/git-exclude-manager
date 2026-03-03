import SwiftUI
import Shared

@main
struct GitExcludeManagerApp: App {
    @StateObject private var patternsVM = PatternsViewModel()
    @StateObject private var repositoryVM = RepositoryViewModel()
    @StateObject private var languageService = LanguageService()

    var body: some Scene {
        WindowGroup {
            PatternsView(
                patternsVM: patternsVM,
                repositoryVM: repositoryVM
            )
            .frame(minWidth: 1200, minHeight: 400)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandMenu(
                NSLocalizedString("menu.language", comment: "Language menu"),
                content: buildLanguageMenuContent
            )
        }
    }

    @ViewBuilder
    private func buildLanguageMenuContent() -> some View {
        ForEach(LanguageService.Language.allCases, id: \.self) { language in
            Button(
                action: { languageService.currentLanguage = language },
                label: {
                    HStack {
                        Text(language.displayName)
                        if languageService.currentLanguage == language {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            )
        }
    }
}
