# Changelog

## v1.0.1 — 2026-10-15

### Added

- **Pattern Clipboard** — a new panel at the top of the right column. Select several patterns with
  ⌘-click / ⇧-click, press **⌘C** (or right-click → *Copy to Pattern Clipboard*) to collect them from any
  repository, then switch repository and **Paste all** (or ⊕ one at a time). Only patterns the repository
  doesn't have yet are added, in one save. Copied patterns also go to the system pasteboard as plain lines.
- **⌘V** pastes pattern lines from anywhere (another repository, a `.gitignore`, an editor); comments and
  blank lines are ignored.
- Help: new *Pattern Clipboard* topic.

### Changed

- The pattern list and right-column panels are now separate views (`PatternListView`, `ClipboardPanel`,
  `SidePanels`, `RepositoryTabBar`); SwiftLint runs with `--strict` in CI.

## v1.0.0 — 2026-10-15

First public release of **Git Exclude Manager**, a native macOS app for editing `.git/info/exclude` —
the per-clone ignore file that is never committed. English and Thai UI.

### Highlights

- **Edit `.git/info/exclude` visually** — add, edit, enable/disable (`#pattern`), delete, and search patterns.
  Every save is atomic and keeps a one-step backup (`exclude.bak`); **Restore Previous** reverts the last save.
- **Your file stays yours** — comments, blank lines and anything the app doesn't understand are written back
  byte-for-byte. git's default header is shown pinned at the top.
- **Sections** — blank lines become draggable section breaks with an optional `# heading`, so you can group
  patterns ("Editors", "Secrets", "Claude Code runtime", …). Drag patterns, sections and comments to reorder.
- **Multiple repositories** — browser-style tabs you can drag to reorder; open tabs, order and selection are
  restored on relaunch. **Drag repository folders from Finder** onto the window to open them (non-repositories
  get a clear warning). Paths are shown as `~/…`.
- **Pattern Suggestions** — patterns your other recent repositories use that this one doesn't, most shared
  first; one click to add.
- **AI Agent (optional)** — chat about your ignore patterns, one-tap Quick Messages, and ✨ Generate Comment.
  Choose Apple Foundation Models (on-device, macOS 26+), Ollama (local), OpenAI, Gemini or Claude; switch
  models from the panel header. API keys are stored in the macOS Keychain.
- **Import / Export** — import any text file including `.gitignore` (merge new patterns or replace all);
  export with a "Show in Finder" confirmation.
- **Native macOS** — a **Repository** menu with shortcuts (⌘O open, ⌘N add pattern, ⇧⌘N new section,
  ⌃Tab / ⌘1…⌘9 switch tabs, ⌘F search), VoiceOver labels, light/dark/system appearance, a built-in Help panel,
  and a red panda icon that renders natively on macOS 26.

### Requirements

- macOS 14 Sonoma or later (Apple Foundation Models needs macOS 26 with Apple Intelligence enabled)
- AI features are optional; cloud providers need your own API key, Ollama needs `ollama serve` running

### Installation

Download `GitExcludeManager-1.0.0.dmg` (and `SHA256SUMS.txt`) from the GitHub release, open it and drag
**Git Exclude Manager** to **Applications**.

This build is **not notarized** (no Developer ID yet), so macOS blocks the first launch once:
open it, then **System Settings → Privacy & Security → Open Anyway** — or run
`xattr -dr com.apple.quarantine "/Applications/GitExcludeManager.app"`.
Then allow the background helper when asked (**System Settings → General → Login Items**);
it only reads and writes `.git/info/exclude` files you open.

### Privacy

- Repository files are read and written locally by a user-level helper — no root privileges, no telemetry.
- When a **cloud** AI provider is selected, the chat sends the repository name and the current
  `.git/info/exclude` content to that provider. Use Ollama or Apple Foundation Models to keep everything on-device.

### License

[MIT](LICENSE) © 2026 Watthajak Jinasam

### Known limitations

- One backup level (`exclude.bak`); multi-step undo is planned.
- A `# heading` on the very first line (no blank line before it) is shown as a comment, not a section.
- Suggestions refresh when you switch repositories, not live while other repositories change.
