# Git Exclude Manager — Phase 1: Static UI Prototype

A macOS menu bar application for managing `.git/info/exclude` files across Git repositories, with bilingual UI support (English/Thai).

## 📚 Documentation

### Quick Start
- **[⚡ Getting Started](.claude/docs/getting-started.md)** — Setup, architecture, and quick start guide

### Development
- **[🔧 Development Guide](.claude/docs/development.md)** — Code style, patterns, testing, and CI/CD
- **[✅ Phase 1 Complete](.claude/docs/phase1-complete.md)** — Implementation summary and deliverables

### Specifications
- **[📋 Requirements](.claude/specs/requirements.md)** — Feature specifications (FR/NFR)
- **[🎨 Design](.claude/specs/design.md)** — Detailed architecture & data models
- **[💡 Decisions](.claude/specs/decisions.md)** — Architecture Decision Records (12 ADRs)
- **[📅 Tasks](.claude/specs/tasks.md)** — Phase breakdown & roadmap

### Strategic Context
- **[🎯 Product Vision](.claude/steering/product.md)** — Product context & goals
- **[🔧 Technical Context](.claude/steering/tech.md)** — Technology stack & patterns
- **[⚠️ Constraints](.claude/steering/constraints.md)** — Limitations & trade-offs
- **[🗺️ Roadmap](.claude/steering/roadmap.md)** — Development timeline

### Code Quality
- **[🤖 CI/CD Pipeline](.github/workflows/ci.yml)** — Automated testing & validation
- **[📖 Copilot Instructions](.github/copilot-instructions.md)** — AI coding guidelines

## Phase 1 Status: Static Prototype

This is the **Phase 1 static prototype** — a visual mockup with no backend functionality. The goal is to validate the UI/UX design before implementing file I/O and XPC communication.

### What Works in Phase 1

✅ **Standard Dock application** — App runs as a normal macOS app with Dock icon  
✅ **Static UI layout** — Repository picker, search bar, pattern list, editor form  
✅ **Bilingual strings** — English and Thai localization files  
✅ **Language switching** — Menu-based language selection (English/Thai) with persistence  
✅ **Mock data** — Sample patterns and repositories for preview  
✅ **SwiftUI previews** — All views render correctly in Xcode Live Preview  
✅ **Disabled interactions** — Buttons and inputs are `.disabled(true)` to indicate prototype status  

### What's NOT Implemented Yet

❌ File I/O (reading/writing `.git/info/exclude`)  
❌ XPC communication with helper daemon  
❌ Actual pattern persistence  
❌ Repository browsing  
❌ Import/export functionality  
❌ Settings/preferences  

---

## Project Structure

```
Sources/
├── GitExcludeManagerApp/          # Main macOS app
│   ├── ViewModels/                # App logic stubs (PatternsViewModel, etc.)
│   ├── Views/                     # SwiftUI components
│   │   ├── PatternsView.swift     # Main content view
│   │   ├── PatternRow.swift       # Individual pattern row
│   │   ├── EditorView.swift       # Add/edit pattern form
│   │   ├── RepositoryPickerView.swift
│   │   └── SearchBar.swift
│   ├── GitExcludeManagerApp.swift # @main entry point with WindowGroup
│   └── Info.plist
├── GitExcludeManagerHelper/       # XPC helper daemon (stub)
│   ├── main.swift                 # Placeholder for Phase 2
│   └── Info.plist
├── Shared/                        # Cross-target types
│   ├── Models/
│   │   └── GitExcludeModels.swift # GitExcludePattern, GitRepository
│   └── HelperProtocol.swift       # XPC protocol (stubs)
Tests/
├── GitExcludeManagerTests.swift   # Unit tests (basic stubs)
Resources/
├── en.lproj/Localizable.strings   # English UI strings
└── th.lproj/Localizable.strings   # Thai UI strings
Package.swift                       # SPM package definition
```

---

## Building & Running Phase 1

### Prerequisites
- macOS 15.0+
- Xcode 16+
- Swift 5.9+

### Build Steps

1. **Clone or open the project:**
   ```bash
   cd /Users/abd-th-012/Documents/SwiftUI/git-exclude-manager
   ```

2. **Build the package:**
   ```bash
   swift build
   ```

3. **Run the app:**
   ```bash
   swift run GitExcludeManager
   ```

   The app will launch and appear in the menu bar (status bar, top right).

### Run Tests

```bash
swift test
```

---

## Viewing the Prototype

### In Xcode

1. Open any view file (e.g., `PatternsView.swift`)
2. Click **Resume** in the Live Preview panel (lower right)
3. The UI renders in real time

### Switching Language (Local Testing)

To preview Thai localization:
1. System Preferences → General → Language & Region → Preferred Languages
2. Add **Thai** and set as primary
3. Restart Xcode or the app
4. UI strings will display in Thai

---

## Design Notes

### UI Layout

**Menu Bar Window:**
- Repository Picker (show current repo path, "Browse..." button)
- Search Bar (filter patterns by text)
- Pattern List (scrollable, 5 sample patterns)
  - Each row shows: toggle button, pattern text, comment (if any), menu button (edit/delete)
- Status Bar (pattern count, add/import/export buttons)

### Mock Data

Five sample patterns are pre-loaded:
1. `*.log` — Log files (enabled)
2. `node_modules/` — NPM dependencies (enabled)
3. `.env` — Environment variables (enabled)
4. `build/` — Build output (disabled/commented)
5. `.DS_Store` — macOS files (enabled)

### Localization

All UI strings are defined in `Localizable.strings` files:
- **English:** `Resources/en.lproj/Localizable.strings`
- **Thai:** `Resources/th.lproj/Localizable.strings`

Add new strings using `NSLocalizedString()` calls in code.

---

## Next Steps (Phase 2)

Once Phase 1 UI is validated, Phase 2 will:
- Implement real file I/O for `.git/info/exclude`
- Build XPC protocol and helper daemon
- Connect UI to data models and services
- Add persistence (UserDefaults for last repo)
- Implement pattern parsing and validation

---

## Architecture Overview

```
┌─────────────────────────────────────┐
│  GitExcludeManagerApp (Dock App)    │
│                                     │
│  PatternsView (UI)                  │
│  └── PatternsViewModel (stubs)      │
│                                     │
│  RepositoryPickerView               │
│  └── RepositoryViewModel (stubs)    │
│                                     │
│  Commands (Language Menu)           │
│  └── LanguageService                │
└──────────────┬──────────────────────┘
               │
               │ Phase 2: XPC
               ↓
┌─────────────────────────────────────┐
│  GitExcludeManagerHelper (Daemon)   │
│  HelperService (Phase 2 impl)       │
│  File I/O operations                │
└─────────────────────────────────────┘
```

---

## Troubleshooting

**Build fails with Swift compiler errors:**
- Ensure all `.swift` files are in the correct source directories
- Check `Package.swift` for target configuration
- Run `swift package describe` to verify package structure

**App doesn't appear in Dock:**
- Ensure `Info.plist` does NOT contain `LSUIElement = YES` (which would hide Dock)
- Verify `CFBundlePackageType` is set to `APPL` in `Info.plist`
- Check Console.app for error messages
- Make sure `GitExcludeManagerApp` scheme is selected in Xcode

**Language switching not persisting:**
- Verify `UserDefaults` key `"app.language"` is being written correctly
- Check System Preferences → General → Language to see system language
- Clear UserDefaults: `defaults delete com.gitexcludemanager.app`

**Localization strings not showing:**
- Verify `.strings` files are in `Resources/{en,th}.lproj/`
- Check file encoding is UTF-8 with BOM
- Rebuild the project after editing `.strings` files
- Verify all string keys exist in both English and Thai files

---

## Contributing

This is a collaborative prototype. To add features or improve the UI:
1. Edit views in `Sources/GitExcludeManagerApp/Views/`
2. Update `.strings` files if adding new UI text
3. Keep Phase 1 backend stubs (don't implement XPC yet)
4. Test in Live Preview before committing

---

## License

© 2026. All rights reserved.

---

## Support

For questions or issues with the prototype:
- Review `.claude/specs/` for design decisions and requirements
- Check `.claude/docs/` for detailed documentation
- Read `.claude/docs/QUICKSTART.md` for quick answers
- See `.claude/docs/PHASE1-CHECKLIST.md` for completion status

