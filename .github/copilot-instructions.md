# GitHub Copilot Instructions — Git Exclude Manager

## Project Context

You are working on **Git Exclude Manager**, a standard macOS application for managing `.git/info/exclude` files with bilingual support (English/Thai) and language switching via app menu.

### Key Information
- **Current Phase:** Phase 2 Complete ✅, Phase 3 Ready to Start 🔄
- **Technology:** Swift 5.9+, SwiftUI, SPM 6.0, XPC
- **Platform:** macOS 14+ only (standard app with Dock icon)
- **Architecture:** MVVM + Clean Architecture
- **External Dependencies:** ZERO (Foundation + SwiftUI only)
- **UI Style:** Standard WindowGroup with command menu (no menu bar integration)

---

## Code Style & Conventions

### Swift Style
- Follow `.swiftlint.yml` configuration strictly
- No compiler warnings allowed
- File length limit: 400 lines (warning), 600 (error)
- Function length limit: 50 lines (warning), 80 (error)
- Line length: 120 characters (warning), 150 (error)

### Naming Conventions
```swift
// Views
PatternsView.swift, PatternRow.swift, EditorView.swift

// ViewModels
PatternsViewModel.swift, EditorViewModel.swift

// Models
GitExcludePattern, GitRepository, HelperError

// Services
XPCService.swift, ValidationService.swift

// Extensions
String+Validation.swift, View+Extensions.swift

// Protocols
HelperProtocol.swift
```

### Code Organization
```swift
// MARK: - Public Interface
// MARK: - Private Methods
// MARK: - Computed Properties
// MARK: - Preview
```

---

## Architecture Patterns

### Models (Value Types)
```swift
public struct GitExcludePattern: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var pattern: String
    public var isEnabled: Bool
    public var comment: String?
    public let createdAt: Date
    public var modifiedAt: Date
}
```

### ViewModels (@MainActor)
```swift
@MainActor
class PatternsViewModel: ObservableObject {
    @Published var patterns: [GitExcludePattern] = []
    @Published var searchText: String = ""
    @Published var errorMessage: String?
    
    // Always use computed properties for filtering
    var filteredPatterns: [GitExcludePattern] {
        patterns.filter { /* ... */ }
    }
}
```

### Views (SwiftUI)
```swift
struct PatternsView: View {
    @ObservedObject var viewModel: PatternsViewModel
    
    var body: some View {
        // UI code
    }
}

#Preview {
    PatternsView(viewModel: PatternsViewModel())
}
```

### Services (@MainActor for UI services)
```swift
@MainActor
class LanguageService: ObservableObject {
    enum Language: String, CaseIterable {
        case english = "en"
        case thai = "th"
        var displayName: String { /* ... */ }
    }
    
    @Published var currentLanguage: Language {
        didSet { /* save to UserDefaults */ }
    }
}
```

---

## Key Principles

### 1. Zero External Dependencies
- Use Foundation/SwiftUI ONLY
- No third-party packages
- No CocoaPods, no Carthage

### 2. Thread Safety
- All ViewModels are `@MainActor`
- All UI Services are `@MainActor`
- Models are `Sendable` (structs)
- XPC callbacks use `@escaping` closures

### 3. Localization
- ALL strings use `NSLocalizedString()`
- No hardcoded strings in UI
- Keys format: `"btn.add"`, `"error.invalidPattern"`, `"menu.language"`
- Supported languages: English, Thai
- Language preference stored in UserDefaults with key `"app.language"`
### 4. Error Handling
```swift
enum HelperError: Error, Sendable {
    case fileReadError(String)
    case fileWriteError(String)
    case invalidRepository(String)
    case permissionDenied
    case connectionFailed
    case invalidData(String)
    case unknown(String)
}
```

### 5. XPC Communication (Phase 2+)
```swift
@objc protocol HelperProtocol: NSObjectProtocol {
    func readExcludeFile(
        repoPath: String,
        completion: @escaping (Data?, NSError?) -> Void
    )
}
```

---

## Frontend Design Guidelines

For comprehensive UI/UX design patterns, accessibility requirements, component library, and localization guidelines, see:

👉 **[`.claude/plugins/frontend-design/skills/frontend-design.md`](./../.claude/plugins/frontend-design/skills/frontend-design.md)**

### Quick Summary

**Design Principles:**
1. **Clarity** — Information hierarchy, visual weight, consistent terminology
2. **Consistency** — Unified colors, interaction patterns, component reuse
3. **Feedback** — Immediate visual response, error communication, loading states
4. **Efficiency** — Minimize friction, smart defaults, keyboard support
5. **Accessibility** — WCAG AA contrast, VoiceOver labels, keyboard navigation

**Key Requirements:**
- Use semantic colors (`.primary`, `.secondary`, `.red`, `.green`) — no hardcoded hex
- Follow 8pt spacing system (8pt, 12pt, 16pt, 20pt multiples)
- Support Dark Mode automatically via semantic colors
- Include `#Preview` block in every view
- All strings localized via `NSLocalizedString()` (en/th)
- Accessibility labels for interactive elements (`accessibilityLabel`, `accessibilityHint`)
- Dynamic Type support (no fixed font sizes)
- Full keyboard navigation (Tab, Space, Return, Escape)

**Components Already Implemented:**
- `SearchBar.swift` — Search field with clear button
- `PatternRow.swift` — List item with toggle, edit, delete actions
- `RepositoryPickerView.swift` — Repository selection dropdown

**When Creating New Views:**
1. Check existing patterns in `Sources/GitExcludeManagerApp/Views/`
2. Reuse atomic components (buttons, inputs, spacing)
3. Follow 12pt section spacing, 8pt element padding
4. Add both light/dark mode previews
5. Test with VoiceOver (System Preferences → Accessibility → VoiceOver)

---

## What to Generate

### When Creating New Files

1. **Views:**
   - Use SwiftUI
   - Include `#Preview` block
   - Observe ViewModels with `@ObservedObject`
   - Use localized strings

2. **ViewModels:**
   - Mark as `@MainActor`
   - Inherit from `ObservableObject`
   - Use `@Published` for state
   - Document incomplete functionality clearly

3. **Models:**
   - Use `struct` (value types)
   - Conform to `Identifiable, Codable, Hashable, Sendable`
   - Keep immutable where possible

4. **Tests:**
   - Test models and ViewModels
   - Use descriptive test names
   - Follow Arrange-Act-Assert pattern

### When Modifying Existing Files

1. **Preserve existing patterns:**
   - Don't change architecture without ADR
   - Keep consistent naming
   - Follow existing code organization

2. **Add documentation:**
   - Document public APIs with `///`
   - Explain complex logic inline
   - Mark future enhancements: `// Phase 3: Add feature X`

3. **Update localization:**
   - Add new strings to both `.strings` files
   - Use descriptive keys
   - Test in both languages

---

## Common Patterns

### Filtering with Search
```swift
var filteredPatterns: [GitExcludePattern] {
    guard !searchText.isEmpty else { return patterns }
    return patterns.filter {
        $0.pattern.localizedCaseInsensitiveContains(searchText) ||
        ($0.comment?.localizedCaseInsensitiveContains(searchText) ?? false)
    }
}
```

### Form Validation
```swift
var isValid: Bool {
    !patternText.trimmingCharacters(in: .whitespaces).isEmpty
}

var errorMessage: String? {
    guard isValid else {
        return NSLocalizedString("error.invalidPattern", comment: "")
    }
    return nil
}
```

### File Representation
```swift
var lineInFile: String {
    let line = isEnabled ? pattern : "# " + pattern
    if let comment = comment, !comment.isEmpty {
        return line + " # " + comment
    }
    return line
}
```

---

## What NOT to Do

### ❌ Don't:
- Add external dependencies (SPM packages)
- Use AppKit views (SwiftUI only)
- Hardcode strings (use localization)
- Create reference types for models (use structs)
- Skip `@MainActor` on ViewModels
- Ignore SwiftLint warnings
- Write files > 400 lines without discussion
- Add features not in specs

### ✅ Do:
- Follow `.swiftlint.yml` rules
- Use value types (structs)
- Localize all strings
- Add `#Preview` to views
- Mark ViewModels as `@MainActor`
- Write unit tests for models
- Keep functions < 50 lines
- Document public APIs

---

## File Locations

### Source Code
```
Sources/
├── Shared/
│   ├── Models/GitExcludeModels.swift
│   └── HelperProtocol.swift
├── GitExcludeManagerApp/
│   ├── GitExcludeManagerApp.swift
│   ├── ViewModels/
│   ├── Views/
│   ├── Services/
│   └── Resources/
│       ├── en.lproj/Localizable.strings
│       └── th.lproj/Localizable.strings
├── GitExcludeManagerHelper/
│   └── main.swift
└── Tests/
```

### Documentation
```
.claude/
├── docs/          # Architecture documentation
├── specs/         # Technical specifications  
│   └── phases/    # Phase-specific task tracking
├── plugins/       # Specialized AI skills
└── steering/      # Strategic context (READ THESE!)
    ├── product.md     # Product vision
    ├── tech.md        # Technical context
    ├── constraints.md # What we can/can't do
    └── roadmap.md     # Development timeline
```

---

## Context Documents (MUST READ)

Before generating code, read these for context:

1. **`.claude/steering/product.md`** — Understand product vision
2. **`.claude/steering/tech.md`** — Understand tech stack
3. **`.claude/steering/constraints.md`** — Know limitations
4. **`.claude/specs/design.md`** — Architecture details
5. **`.claude/specs/decisions.md`** — Why we chose this design
6. **`.claude/specs/phases/README.md`** — Current phase status and tasks
7. **`.claude/docs/architecture.md`** — System architecture overview

---

## Localization Examples

### English (`en.lproj/Localizable.strings`)
```
"btn.add" = "Add";
"btn.edit" = "Edit";
"error.invalidPattern" = "Pattern cannot be empty";
```

### Thai (`th.lproj/Localizable.strings`)
```
"btn.add" = "เพิ่ม";
"btn.edit" = "แก้ไข";
"error.invalidPattern" = "รูปแบบไม่สามารถว่างเปล่าได้";
```

### Usage in Code
```swift
Button(action: addPattern) {
    Text(NSLocalizedString("btn.add", comment: "Add pattern button"))
}
```

---

## Testing Patterns

### Model Tests
```swift
func testGitExcludePatternCreation() {
    let pattern = GitExcludePattern(
        pattern: "*.log",
        isEnabled: true,
        comment: "Log files"
    )
    
    XCTAssertEqual(pattern.pattern, "*.log")
    XCTAssertTrue(pattern.isEnabled)
    XCTAssertTrue(pattern.isValid)
}
```

### ViewModel Tests (Phase 2+)
```swift
@MainActor
func testFilterPatterns() async {
    let vm = PatternsViewModel()
    vm.searchText = "log"
    
    let filtered = vm.filteredPatterns
    XCTAssertTrue(filtered.allSatisfy { 
        $0.pattern.contains("log") 
    })
}
```

---

## Phase-Specific Guidelines

### Phase 1 (Complete ✅)
- All stubs have been replaced in Phase 2
- Mock data still used in `#Preview` blocks

### Phase 2 (Complete ✅)
- All CRUD operations wired to XPC helper
- `ExcludeFileService.writeExcludeFile()` atomic write
- `RepositoryViewModel.browseRepository()` uses NSOpenPanel
- All `.disabled(true)` removed from views
- 30 unit tests passing

### Phase 3 (Current 🔄)
When implementing Phase 3 features:
- `SMAppService.register()` — helper auto-start on first launch
- File backup before writes + restore on failure
- Multi-repository switcher UI (recents already in UserDefaults)
- Delete confirmation alert
- Settings window with language picker
- ⌘F keyboard shortcut for search focus
- `startAccessingSecurityScopedResource()` for imported files


---

## Quick Commands

### Build & Test
```bash
swift build              # Build project
swift test               # Run tests
swiftlint                # Check code style
swift run GitExcludeManager  # Run app
```

### Documentation
```bash
cat .claude/steering/product.md    # Product context
cat .claude/steering/tech.md       # Tech context
cat .claude/specs/design.md        # Architecture
cat .claude/specs/decisions.md     # ADRs
cat .claude/specs/phases/README.md # Current phase tasks
```

---

## Common Tasks

### Add New View
1. Create in `Sources/GitExcludeManagerApp/Views/`
2. Use SwiftUI
3. Observe ViewModel with `@ObservedObject`
4. Add `#Preview` block
5. Localize all strings
6. Run SwiftLint

### Add New Model
1. Create in `Sources/Shared/Models/`
2. Use `struct`
3. Conform to `Identifiable, Codable, Hashable, Sendable`
4. Add computed properties as needed
5. Write unit tests

### Add Localized String
1. Add key to `en.lproj/Localizable.strings`
2. Add translation to `th.lproj/Localizable.strings`
3. Use `NSLocalizedString("key", comment: "description")`

---

## Developer Info

**Developer:** Solo developer (Thai speaker, English proficient)  
**Timeline:** Part-time (~10-15 hours/week)  
**Budget:** $0 (open-source)  
**Target Release:** April 30, 2026 (v1.0.0)

---

## Support & Questions

- **Architecture questions:** Read `.claude/specs/design.md` and `.claude/specs/decisions.md`
- **Product questions:** Read `.claude/steering/product.md`
- **Technical questions:** Read `.claude/steering/tech.md`
- **Phase planning:** Read `.claude/steering/roadmap.md`
- **Current tasks:** Read `.claude/specs/phases/README.md`

---

## Summary

When generating code for this project:
1. ✅ Follow SwiftLint rules
2. ✅ Use value types (structs)
3. ✅ Localize all strings (en/th)
4. ✅ Mark ViewModels as `@MainActor`
5. ✅ Add `#Preview` to views
6. ✅ Zero external dependencies
7. ✅ Read context docs in `.claude/steering/`
8. ✅ Keep functions < 50 lines
9. ✅ Document public APIs
10. ✅ Write tests for models

**Current Status:** Phase 3 In Progress 🔄 — Aligning Swift UI with `.prototype/` HTML Reference Design 🚀

---

**Last Updated:** March 4, 2026  
**Version:** 1.3  
**For:** GitHub Copilot, Claude, and AI Assistants

