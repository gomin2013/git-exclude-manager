# Changelog

## v1.1.5 — 2026-10-22

### Changed

- **Website: links to the whole Gomin family** — every page's footer now has two rows: this site's pages
  (Download, About, Privacy, Terms), then Gomin Apps, Hosts Manager, SwiftUI Mac Skills (Claude Code skills
  built from these apps), the developer profile, GitHub and Sponsor — in all 12 languages. The app itself is unchanged.

### Installation

Download `GitExcludeManager-1.1.5.dmg` (and `SHA256SUMS.txt`), drag **Git Exclude Manager** to **Applications**
(replace the old copy) and allow the first launch in **System Settings → Privacy & Security → Open Anyway** (or
`xattr -dr com.apple.quarantine "/Applications/GitExcludeManager.app"`). Updating: if a repository says the helper
isn't responding, turn Git Exclude Manager **off and on again** in **System Settings → General → Login Items &
Extensions**. Requires an Apple silicon Mac with macOS 14 or later.

## v1.1.4 — 2026-10-22

### Added

- **Drop a repository on the Dock icon** — drag a repository folder from Finder onto Git Exclude Manager in the Dock
  (or use **Open With**) and it opens as a tab, whether the app is running or not. A folder that isn't a git
  repository gets the usual message naming it. Git Exclude Manager never becomes the default app for folders.

### Changed

- **One main window** — opening a repository from outside the app always uses the window you have; it no longer opens a
  second copy of it. Closing the window still keeps the app in the Dock; click the icon to bring it back.

### Installation

Download `GitExcludeManager-1.1.4.dmg` (and `SHA256SUMS.txt`), drag **Git Exclude Manager** to **Applications**
(replace the old copy) and allow the first launch in **System Settings → Privacy & Security → Open Anyway** (or
`xattr -dr com.apple.quarantine "/Applications/GitExcludeManager.app"`). Updating: if a repository says the helper
isn't responding, turn Git Exclude Manager **off and on again** in **System Settings → General → Login Items &
Extensions**. Requires an Apple silicon Mac with macOS 14 or later.

## v1.1.3 — 2026-10-22

### Changed

- **Support moved to GitHub Sponsors** — the link in **About** (now with a ♥), the website footer, the README and the
  repository's **Sponsor** button all go to [github.com/sponsors/gomin2013](https://github.com/sponsors/gomin2013)
  instead of Ko-fi, in every language. Git Exclude Manager stays free.

### Installation

Download `GitExcludeManager-1.1.3.dmg` (and `SHA256SUMS.txt`), drag **Git Exclude Manager** to **Applications**
(replace the old copy) and allow the first launch in **System Settings → Privacy & Security → Open Anyway** (or
`xattr -dr com.apple.quarantine "/Applications/GitExcludeManager.app"`). Updating: if a repository says the helper
isn't responding, turn Git Exclude Manager **off and on again** in **System Settings → General → Login Items &
Extensions**. Requires an Apple silicon Mac with macOS 14 or later.

## v1.1.2 — 2026-10-22

### Changed

- **Shorter model lists** — **Load models** for OpenAI, Gemini and Claude now shows just the newest low-cost model of
  each family (GPT mini / nano, Gemini Flash-Lite / Flash, Claude Haiku / Sonnet) instead of dozens of previews, TTS,
  image models and dated snapshots; the first is marked **(Recommended)**. Ollama still lists every model you pulled,
  and if a provider renames its models the full list comes back.

### Added

- **Support on Ko-fi** — a link in **About** (and in the website footer). Git Exclude Manager stays free.

### Installation

Download `GitExcludeManager-1.1.2.dmg` (and `SHA256SUMS.txt`), drag **Git Exclude Manager** to **Applications**
(replace the old copy) and allow the first launch in **System Settings → Privacy & Security → Open Anyway** (or
`xattr -dr com.apple.quarantine "/Applications/GitExcludeManager.app"`). Updating: if a repository says the helper
isn't responding, turn Git Exclude Manager **off and on again** in **System Settings → General → Login Items &
Extensions**. Requires an Apple silicon Mac with macOS 14 or later.

## v1.1.1 — 2026-10-21

Fixes on top of 1.1.0 for anyone updating from an earlier version — everything in 1.1.0 below is included.

### Fixed

- **A repository could load forever after an update** — macOS keeps the helper allowed but may not start the new one
  until you turn it off and on in Login Items, and nothing ever answered. Requests now give up after 10 s and say
  where to fix it (System Settings › General › Login Items & Extensions).

### Installation

Download `GitExcludeManager-1.1.1.dmg` (and `SHA256SUMS.txt`), drag **Git Exclude Manager** to **Applications**
(replace the old copy) and allow the first launch in **System Settings → Privacy & Security → Open Anyway** (or
`xattr -dr com.apple.quarantine "/Applications/GitExcludeManager.app"`). Updating: if a repository says the helper
isn't responding, turn Git Exclude Manager **off and on again** in **System Settings → General → Login Items &
Extensions**. Requires an Apple silicon Mac with macOS 14 or later.

## v1.1.0 — 2026-10-21

A redesign of the main window — same layout as before (and as [Hosts Manager](https://github.com/gomin2013/hosts-manager)),
modernised.

### Added

- **History** — a new side panel listing the last 30 edits (add, edit, turn on/off, delete, rename, reorder, paste,
  import). Click a state to go back to it; later states stay dimmed until your next edit. Pin states you want to keep
  (the file as opened is pinned for you) and remove one you don't need with its trash button. Replaces the **Restore Previous** button (the menu item stays and still
  reverts the last save from `exclude.bak`).
- **Side panels as a tool window** — an icon rail on the right edge opens one panel at a time at full height:
  Clipboard · Suggestions · History · AI Agent · Help, then Appearance · Language · About at the bottom (⌥⌘1…8,
  **–** hides the panel and gives the list the full width).
- **Appearance & colour** (side panel at the bottom of the rail) — Light / Dark / System, 16 accent colours and
  8 gradient themes. **Language** and **About** are the panels below it; the window has no toolbar any more.
- **12 languages** — English, ไทย, 日本語, 한국어, Tiếng Việt, Bahasa Indonesia, Bahasa Melayu, Filipino, 简体中文,
  繁體中文, Español and Русский. The **Language** panel searches by native name, English name, the name in your
  current language or code; the first launch follows your macOS language.
- **Help › Git Exclude Manager Help** (⌘?) opens the Help side panel (it used to say "Help isn't available").
- **`-demo` launch mode** — `open GitExcludeManager.app --args -demo` shows three sample repositories held in memory,
  with their own UI settings; nothing is read from or written to disk. Website screenshots come from it.
- **AI Agent** — answers stream in with live steps (attached → waiting → thinking → writing) and seconds, the model's
  thinking when the provider sends it (Ollama, Claude, Gemini), Markdown answers with copyable code blocks, and **Stop**.
  A start page with one-click questions on first launch, and a note that the exclude file is sent with each question.
- Keyboard: **Space** turns selected patterns on/off, **⌫** deletes them, **Return** / double-click edits a pattern or
  renames a section.
- **Welcome screen** when no repository is open (what a new user sees first): Open Repository ⌘O goes straight to
  the folder picker, drop a folder anywhere, recent repositories, Help / Website / GitHub. Help is the first panel.

### Changed

- **New app icon and mascot** — a Liquid Glass robot whose visor shows the hidden eye (16–64 px keep the flat
  eye-slash); the website mascot is the same robot, waving.
- **Look** — Liquid Glass on macOS 26 (material on 14–15) for search, buttons and the side panel; Sukhumvit Set for
  interface text, SF Mono for patterns; checkboxes instead of green circles; no cards; edit / delete sit at the end of
  every row in a quiet secondary colour (no wall of red trash cans — and no hover-only buttons, which stuttered while
  scrolling); sections get an accent bar; git's default header folds away.
- Repository tabs fill with the chosen accent; × shows on the selected or hovered tab — closing the last one shows
  the Welcome screen.
- The Add / Edit sheet has the same layout as Hosts Manager (labels on the left, Generate Comment under Comment,
  Return saves, Esc cancels). Thai uses "หมายเหตุ" for comment.
- Deleting no longer asks for confirmation — every delete can be undone in History.
- Appearance moved from the Settings menu to the palette button; Language and About are their own panels (Settings
  will come back once there is more to set).
- History lists start at the top of the panel.

### Fixed

- **"Add heading…" looked frozen** — clicking a section heading never let you type (the list took the click). A new
  section now opens its heading for typing (scrolled into view); double-click or Return renames; Esc cancels.
- Empty states: the Welcome screen, "No Patterns" with an Add button, and "No Results" while searching.
- **A pattern with a comment was never ignored** — v1.0 saved `AGENTS.local.md # notes`, but git has no end-of-line
  comments, so it read the whole line as one pattern. Comments are now saved on their own `## notes` line above the
  pattern, and files saved the old way are rewritten when you open the repository (the old file stays as `exclude.bak`).

### Website

- The site speaks the same 12 languages: a language button opens a searchable list; English and Thai are built in,
  the others load on demand. A Thai page at `/git-exclude-manager/th/` for search engines.
- Phones: Download / About become icons, the app name and the language code show when there is room.
- History is 30 edits.

## v1.0.2 — 2026-10-17

### Added

- **Website** — [gomin2013.github.io/git-exclude-manager](https://gomin2013.github.io/git-exclude-manager/)
  (Home, Download, About, Privacy Policy, Terms of Use), English and Thai, served from `main` → `/docs`.
  The Download page links the latest release's DMG.
- README: link to the sibling app [Hosts Manager](https://github.com/gomin2013/hosts-manager) and its website.

### Changed

- No app changes; version bumped so the release matches the website.

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
