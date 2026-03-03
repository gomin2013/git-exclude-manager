# Realistic Prototype

This folder contains a realistic interactive prototype for Git Exclude Manager with AI assistant integration.

## File

- `index.html` - Single-file prototype (HTML + CSS + JavaScript)

## Included Behaviors

### Core Features
- English/Thai language switch
- **Repository Tab Bar** - Open & manage multiple repositories simultaneously
- Repository selector with simulated loading state
- Search and live filtering
- Pattern list with enable/disable toggle
- Add/Edit modal with validation
- Delete confirmation
- Pattern count status updates
- **Drag-to-reorder** patterns (disabled while searching)

### AI Agent Features
- **Settings Manager** - Configure AI API (Provider, Key, Model, Temperature)
- **AI Chat Panel** - Right sidebar with interactive AI assistant
- **Quick Prompts** - Pre-defined questions for common tasks
- **Mock Responses** - Context-aware replies based on keywords
- **Status Badge** - Visual indicator for API configuration
- **Validation** - Warns if API key is not configured
- **AI Generate Comment** - Auto-generates contextual comments for patterns

## AI Chat Capabilities (Mock)

The AI agent can respond to:
- Pattern suggestions (`"suggest patterns"`)
- Syntax explanations (`"explain pattern"`)
- Optimization tips (`"optimize patterns"`)
- General gitignore questions

## AI Generate Comment

When adding or editing a pattern:
1. Enter a pattern (e.g., `*.log`, `node_modules/`, `.env`)
2. **"✨ AI Generate"** button appears automatically
3. Click to generate a contextual comment (e.g., "Log files", "NPM dependencies")
4. Generated comment is inserted; edit as needed
5. Supported suggestions include common patterns like:
   - `*.log` → "Log files"
   - `node_modules/` → "NPM dependencies"
   - `.env` → "Environment variables"
   - `build/` → "Build output"
   - `.DS_Store` → "macOS system files"
   - ...and many more

## Notes

- This is mock-only UI behavior (no real AI API calls)
- Responses are generated client-side based on keyword matching
- Settings are persisted in browser localStorage
- Import/Export buttons are intentionally disabled for this prototype slice
- Window width is 1600px for 3-column layout

## Quick Run

Open `index.html` directly in a browser, or use a local server:

```bash
cd .prototype
python3 -m http.server 8080
```

Then open <http://localhost:8080>.

## Testing Features

### Repository Tab Bar
1. Below the toolbar, notice tabs for each repository: "git-exclude-manager", "MyApp", "Website"
2. Click any tab to switch repositories and see different patterns
3. Each repository maintains its own pattern list independently
4. Select a new repository from the "Repository" dropdown
5. A new tab appears and becomes active
6. Click the **×** button on a tab to close it (last tab cannot be closed)
7. Patterns, search state, and AI settings persist per tab

### AI Settings & Chat
1. Click **Settings** button in toolbar
2. Enter any API key (e.g., `sk-test123`)
3. Save settings
4. Notice the badge changes from "Not Set" to "Configured"
5. Type a question in the AI chat input or click quick prompts
6. See mock AI responses appear in the chat panel

### Drag-to-Reorder
1. Hover over a pattern row to see grab cursor
2. Drag and drop to reorder patterns
3. Reordering is disabled while searching (type in search to disable, clear to enable)

### AI Generate Comment
1. Click **Add** or **Edit** on a pattern
2. Enter a pattern (e.g., `*.log`, `.env`, `build/`)
3. **"✨ AI Generate"** button appears
4. Click to auto-fill a contextual comment
5. Edit the comment if needed, then save


