import AppKit

/// Files and folders dropped on the Dock icon (or opened with Finder's "Open With") arrive here — on a cold launch
/// before any window exists — so they wait until the window sets `onOpen`. What the Dock icon accepts comes from
/// `CFBundleDocumentTypes` in Info.plist; `LSHandlerRank` Alternate keeps the app from becoming Finder's default for it.
@MainActor
final class DockDropDelegate: NSObject, NSApplicationDelegate {
    var onOpen: (([URL]) -> Void)? {
        didSet { flush() }
    }
    private(set) var pending: [URL] = []

    /// A `Window` scene quits the app when it closes; keep it in the Dock like before (click the icon to reopen).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func application(_ application: NSApplication, open urls: [URL]) {
        pending += urls
        flush()
    }

    private func flush() {
        guard let onOpen, !pending.isEmpty else { return }
        let urls = pending
        pending = []
        onOpen(urls)
    }
}
