/* =============================================================
   main.js — Application logic for main.html
   Depends on: shared.js (loaded first)
   ============================================================= */

// ── Query param & initial repo ─────────────────────────────
const urlParams      = new URLSearchParams(window.location.search);
const openRepoParam  = urlParams.get("repo");
const initialRepoId  = (openRepoParam && MOCK_PATTERNS[openRepoParam]) ? openRepoParam : "repo1";

// ── App state ──────────────────────────────────────────────
const state = {
  language:          loadStoredLanguage(),
  theme:             loadStoredTheme(),
  repositories:      MOCK_REPOSITORIES,
  searchText:        "",
  loading:           false,
  error:             "",
  editingId:         null,
  draggingPatternId: null,
  activeTabId:       initialRepoId,
  openRepos:         { [initialRepoId]: { patterns: MOCK_PATTERNS[initialRepoId] } },
  settings:          loadStoredSettings({ provider: "openai", apiKey: "" }),
  chat:              { messages: [], isTyping: false }
};

// Shorthand using current language
function tl(key) { return t(key, state.language); }

// ── DOM refs ───────────────────────────────────────────────
const els = {
  windowTitle:           document.getElementById("windowTitle"),
  backLinkLabel:         document.getElementById("backLinkLabel"),
  langEnglish:           document.getElementById("langEnglish"),
  langThai:              document.getElementById("langThai"),
  repoTabs:              document.getElementById("repoTabsBar"),
  openRepoButton:        document.getElementById("openRepoButton"),
  openRepoDialog:        document.getElementById("openRepoDialog"),
  openRepoTitle:         document.getElementById("openRepoTitle"),
  openRepoRecentLabel:   document.getElementById("openRepoRecentLabel"),
  openRepoList:          document.getElementById("openRepoList"),
  openRepoEmpty:         document.getElementById("openRepoEmpty"),
  openRepoBrowseButton:  document.getElementById("openRepoBrowseButton"),
  openRepoCloseButton:   document.getElementById("openRepoCloseButton"),
  // Middle panel
  repoName:              document.getElementById("repoName"),
  repoPath:              document.getElementById("repoPath"),
  errorText:             document.getElementById("errorText"),
  searchInput:           document.getElementById("searchInput"),
  clearSearch:           document.getElementById("clearSearch"),
  addButton:             document.getElementById("addButton"),
  previewRawButton:      document.getElementById("previewRawButton"),
  importButton:          document.getElementById("importButton"),
  exportButton:          document.getElementById("exportButton"),
  loadingState:          document.getElementById("loadingState"),
  emptyState:            document.getElementById("emptyState"),
  list:                  document.getElementById("list"),
  patternCountText:      document.getElementById("patternCountText"),
  hintText:              document.getElementById("hintText"),
  // Editor dialog
  dialog:                document.getElementById("editorDialog"),
  dialogTitle:           document.getElementById("dialogTitle"),
  patternInput:          document.getElementById("patternInput"),
  commentInput:          document.getElementById("commentInput"),
  dialogError:           document.getElementById("dialogError"),
  editorForm:            document.getElementById("editorForm"),
  editorCancelButton:    document.getElementById("editorCancelButton"),
  editorSaveButton:      document.getElementById("editorSaveButton"),
  generateCommentButton: document.getElementById("generateCommentButton"),
  generateCommentHint:   document.getElementById("generateCommentHint"),
  // Settings dialog
  settingsButton:        document.getElementById("settingsButton"),
  settingsDropdown:      document.getElementById("settingsDropdown"),
  themeSystem:           document.getElementById("themeSystem"),
  themeLight:            document.getElementById("themeLight"),
  themeDark:             document.getElementById("themeDark"),
  openAiSettingsItem:    document.getElementById("openAiSettingsItem"),
  aiApiStatusBadge:      document.getElementById("aiApiStatusBadge"),
  openHelpItem:          document.getElementById("openHelpItem"),
  openAboutItem:         document.getElementById("openAboutItem"),
  settingsDialog:        document.getElementById("settingsDialog"),
  settingsForm:          document.getElementById("settingsForm"),
  settingsProvider:      document.getElementById("settingsProvider"),
  settingsApiKey:        document.getElementById("settingsApiKey"),
  settingsAutoNote:      document.getElementById("settingsAutoNote"),
  settingsCancelButton:  document.getElementById("settingsCancelButton"),
  settingsSaveButton:    document.getElementById("settingsSaveButton"),
  // About / Help dialogs
  aboutDialog:           document.getElementById("aboutDialog"),
  aboutCloseButton:      document.getElementById("aboutCloseButton"),
  helpDialog:            document.getElementById("helpDialog"),
  helpCloseButton:       document.getElementById("helpCloseButton"),
  // AI chat
  chatMessages:          document.getElementById("chatMessages"),
  chatInput:             document.getElementById("chatInput"),
  chatSendButton:        document.getElementById("chatSendButton"),
  aiStatusBadge:         document.getElementById("aiStatusBadge"),
  // Raw preview dialog
  rawPreviewDialog:      document.getElementById("rawPreviewDialog"),
  rawPreviewTitle:       document.getElementById("rawPreviewTitle"),
  rawPreviewPath:        document.getElementById("rawPreviewPath"),
  rawPreviewContent:     document.getElementById("rawPreviewContent"),
  rawPreviewCopyButton:  document.getElementById("rawPreviewCopyButton"),
  rawPreviewCloseButton: document.getElementById("rawPreviewCloseButton")
};

// ── Helpers ────────────────────────────────────────────────
function getActivePatterns() {
  return state.openRepos[state.activeTabId]?.patterns ?? [];
}

function getFilteredPatterns() {
  const q = state.searchText.trim().toLowerCase();
  const all = getActivePatterns();
  if (!q) return all;
  return all.filter(item =>
    item.pattern.toLowerCase().includes(q) ||
    item.comment.toLowerCase().includes(q)
  );
}

function formatCount(total, enabled) {
  return tl("status.patternsCount")
    .replace("%d", String(total))
    .replace("%d", String(enabled));
}

// ── Tab management ─────────────────────────────────────────
function switchTab(repoId) {
  state.activeTabId = repoId;
  state.searchText  = "";
  els.searchInput.value = "";
  const repo = state.repositories.find(r => r.id === repoId);
  if (repo) saveRecentRepo(repo);
  render();
}

function closeTab(repoId) {
  if (Object.keys(state.openRepos).length === 1) return;
  delete state.openRepos[repoId];
  if (state.activeTabId === repoId) {
    state.activeTabId = Object.keys(state.openRepos)[0];
  }
  render();
}

// ── Drag & reorder ─────────────────────────────────────────
function movePatternBeforeTarget(draggingId, targetId) {
  if (!draggingId || !targetId || draggingId === targetId) return;
  const patterns  = getActivePatterns();
  const fromIndex = patterns.findIndex(i => i.id === draggingId);
  const toIndex   = patterns.findIndex(i => i.id === targetId);
  if (fromIndex < 0 || toIndex < 0) return;
  const [moved] = patterns.splice(fromIndex, 1);
  patterns.splice(fromIndex < toIndex ? toIndex - 1 : toIndex, 0, moved);
}

// ── Render: tabs ───────────────────────────────────────────
function renderRepoTabs() {
  const bar    = els.repoTabs;
  const addBtn = els.openRepoButton;
  // Remove only tab wraps, leave + button intact
  bar.querySelectorAll(".repo-tab-wrap").forEach(n => n.remove());

  const tabCount = Object.keys(state.openRepos).length;

  Object.keys(state.openRepos).forEach(repoId => {
    const repo = state.repositories.find(r => r.id === repoId);
    if (!repo) return;

    const tab = document.createElement("button");
    tab.className = "repo-tab" + (state.activeTabId === repoId ? " active" : "");
    tab.textContent = repo.name;
    tab.addEventListener("click", () => switchTab(repoId));

    const wrap = document.createElement("div");
    wrap.className = "repo-tab-wrap";
    wrap.appendChild(tab);

    if (tabCount > 1) {
      const closeBtn = document.createElement("button");
      closeBtn.className = "repo-tab close-btn";
      closeBtn.textContent = "×";
      closeBtn.title = "Close tab";
      closeBtn.addEventListener("click", ev => { ev.stopPropagation(); closeTab(repoId); });
      wrap.appendChild(closeBtn);
    }

    bar.insertBefore(wrap, addBtn);
  });
}

// ── Render: pattern list ───────────────────────────────────
function renderPatterns() {
  const visible       = getFilteredPatterns();
  const all           = getActivePatterns();
  const enabledCount  = all.filter(i => i.isEnabled).length;
  const canReorder    = state.searchText.trim().length === 0;

  els.patternCountText.textContent = formatCount(all.length, enabledCount);
  els.loadingState.hidden          = !state.loading;
  els.list.hidden                  = state.loading;

  if (state.loading) return;

  if (visible.length === 0) {
    els.emptyState.hidden      = false;
    els.emptyState.textContent = tl("message.noPatterns");
    els.list.innerHTML         = "";
    return;
  }

  els.emptyState.hidden = true;
  els.list.innerHTML    = "";

  visible.forEach(item => {
    const row = document.createElement("div");
    row.className = ["row",
      item.isEnabled ? "" : "disabled",
      canReorder ? "" : "reorder-disabled"
    ].join(" ").trim();

    // Drag handle
    const handle = document.createElement("div");
    handle.className = "drag-handle";
    handle.textContent = "⠿";
    handle.title = canReorder ? "Drag to reorder" : "Drag disabled while searching";

    if (canReorder) {
      handle.addEventListener("mousedown", () => { row.draggable = true; });
      row.addEventListener("dragstart", ev => {
        if (!row.draggable) { ev.preventDefault(); return; }
        state.draggingPatternId = item.id;
        row.classList.add("dragging");
      });
      row.addEventListener("dragend", () => {
        row.draggable = false;
        state.draggingPatternId = null;
        row.classList.remove("dragging");
        document.querySelectorAll(".row.drop-target").forEach(n => n.classList.remove("drop-target"));
      });
      row.addEventListener("dragover", ev => {
        if (!state.draggingPatternId) return;
        ev.preventDefault();
        row.classList.add("drop-target");
      });
      row.addEventListener("dragleave", ev => {
        if (!row.contains(ev.relatedTarget)) row.classList.remove("drop-target");
      });
      row.addEventListener("drop", ev => {
        ev.preventDefault();
        row.classList.remove("drop-target");
        movePatternBeforeTarget(state.draggingPatternId, item.id);
        renderPatterns();
      });
    }

    // Toggle
    const toggle = document.createElement("button");
    toggle.className = "toggle " + (item.isEnabled ? "on" : "");
    toggle.title = item.isEnabled ? "Disable pattern" : "Enable pattern";
    toggle.addEventListener("click", ev => {
      ev.stopPropagation();
      const target = getActivePatterns().find(p => p.id === item.id);
      if (target) target.isEnabled = !target.isEnabled;
      renderPatterns();
    });

    // Body
    const body = document.createElement("div");
    const patEl = document.createElement("div");
    patEl.className   = "pattern";
    patEl.textContent = item.pattern;
    body.appendChild(patEl);
    if (item.comment) {
      const comEl = document.createElement("div");
      comEl.className   = "comment";
      comEl.textContent = item.comment;
      body.appendChild(comEl);
    }

    // Actions
    const actions = document.createElement("div");
    actions.className = "actions";

    const editBtn = document.createElement("button");
    editBtn.textContent = tl("btn.edit");
    editBtn.addEventListener("click", () => openEditor(item.id));

    const delBtn = document.createElement("button");
    delBtn.textContent = tl("btn.delete");
    delBtn.addEventListener("click", () => {
      if (!window.confirm(tl("dialog.deleteConfirm"))) return;
      state.openRepos[state.activeTabId].patterns =
        getActivePatterns().filter(p => p.id !== item.id);
      renderPatterns();
    });

    actions.append(editBtn, delBtn);
    row.append(handle, toggle, body, actions);
    els.list.appendChild(row);
  });
}

// ── Render: AI chat ────────────────────────────────────────
function renderChat() {
  els.chatMessages.innerHTML = "";

  if (state.chat.messages.length === 0) {
    const welcome = document.createElement("div");
    welcome.className   = "chat-message system";
    welcome.textContent = tl("chat.welcome");
    els.chatMessages.appendChild(welcome);
    return;
  }

  state.chat.messages.forEach(msg => {
    const div = document.createElement("div");
    div.className   = "chat-message " + msg.role;
    div.textContent = msg.content;
    els.chatMessages.appendChild(div);
  });

  if (state.chat.isTyping) {
    const typing = document.createElement("div");
    typing.className   = "chat-message system";
    typing.textContent = "AI is typing...";
    els.chatMessages.appendChild(typing);
  }

  els.chatMessages.scrollTop = els.chatMessages.scrollHeight;
}


// ── Render: full page ──────────────────────────────────────
function render() {
  document.documentElement.lang = state.language;
  const activeRepo = state.repositories.find(r => r.id === state.activeTabId);
  document.title = (activeRepo ? activeRepo.name + " — " : "") + tl("window.title");
  els.windowTitle.textContent   = tl("window.title");
  els.backLinkLabel.textContent = tl("nav.back");
  document.querySelectorAll("[data-i18n]").forEach(n => {
    if (n.childElementCount > 0) {
      const textNodes = [...n.childNodes].filter(c => c.nodeType === Node.TEXT_NODE);
      const label = " " + tl(n.dataset.i18n);
      if (textNodes.length > 0) { textNodes[textNodes.length - 1].textContent = label; }
      else { n.appendChild(document.createTextNode(label)); }
    } else {
      n.textContent = tl(n.dataset.i18n);
    }
  });
  document.querySelectorAll("[data-i18n-placeholder]").forEach(n => { n.placeholder = tl(n.dataset.i18nPlaceholder); });
  document.querySelectorAll("[data-i18n-title]").forEach(n => { n.title = tl(n.dataset.i18nTitle); });
  els.hintText.textContent     = tl("hint.mock") + " " + tl("hint.reorder");
  els.clearSearch.textContent  = state.language === "th" ? "ล้าง" : "Clear";
  els.loadingState.textContent = state.language === "th" ? "กำลังโหลด..." : "Loading...";

  // Update repo info block
  els.repoName.textContent  = activeRepo ? activeRepo.name : tl("status.noRepository");
  els.repoPath.textContent  = activeRepo ? activeRepo.path : "—";
  els.errorText.textContent = state.error;

  renderRepoTabs();
  renderPatterns();
  renderChat();
  renderAiStatus();
  applyDropdownI18n();
}

// ── Editor dialog ──────────────────────────────────────────
function openEditor(id) {
  state.editingId = id;
  const editing = getActivePatterns().find(i => i.id === id) ?? null;
  els.dialogError.textContent    = "";
  els.patternInput.value         = editing ? editing.pattern : "";
  els.commentInput.value         = editing ? editing.comment : "";
  els.dialogTitle.textContent    = tl(editing ? "btn.edit" : "btn.add");
  if (els.generateCommentHint) {
    els.generateCommentHint.textContent = els.patternInput.value.trim()
      ? "" : tl("hint.generateCommentField");
  }
  updateGenerateButtonVisibility();
  els.dialog.showModal();
}

function savePattern() {
  const pattern = els.patternInput.value.trim();
  const comment = els.commentInput.value.trim();

  if (!pattern) {
    els.dialogError.textContent = tl("error.invalidPattern");
    return;
  }

  const active = getActivePatterns();
  if (state.editingId) {
    const target = active.find(i => i.id === state.editingId);
    if (target) { target.pattern = pattern; target.comment = comment; }
  } else {
    active.unshift({ id: crypto.randomUUID(), pattern, comment, isEnabled: true });
  }

  els.dialog.close();
  state.editingId = null;
  renderPatterns();
}

function updateGenerateButtonVisibility() {
  const hasPattern = els.patternInput.value.trim().length > 0;
  els.generateCommentButton.hidden = !hasPattern;
  if (els.generateCommentHint) {
    els.generateCommentHint.textContent = hasPattern ? "" : tl("hint.generateCommentField");
  }
}

function generateCommentForPattern() {
  const pattern = els.patternInput.value.trim();
  if (!pattern) return;

  els.generateCommentButton.disabled    = true;
  els.generateCommentButton.textContent = tl("label.aiGenerating");

  const suggestions = {
    "*.log": "Log files", "*.tmp": "Temporary files", "*.bak": "Backup files",
    "node_modules": "NPM dependencies", "node_modules/": "NPM dependencies",
    ".env": "Environment variables", ".env.local": "Local environment overrides",
    ".venv": "Python virtual environment", "venv/": "Python virtual environment",
    "build": "Build output", "build/": "Build output",
    "dist": "Distribution files", "dist/": "Distribution files",
    ".DS_Store": "macOS system files", "Thumbs.db": "Windows thumbnail cache",
    ".idea": "IDE configuration", ".vscode": "VS Code settings",
    "*.swp": "Vim swap files", ".gradle": "Gradle build directory",
    ".m2": "Maven dependencies cache"
  };

  setTimeout(() => {
    const generated = suggestions[pattern] ?? suggestions[pattern + "/"] ??
      "Exclude " + pattern + " files from version control";
    els.commentInput.value = els.commentInput.value.trim()
      ? generated + " (" + els.commentInput.value + ")"
      : generated;
    els.generateCommentButton.disabled    = false;
    els.generateCommentButton.textContent = tl("btn.generateComment");
  }, 600 + Math.random() * 400);
}

// ── Raw preview ────────────────────────────────────────────
function generateRawContent() {
  const patterns = getActivePatterns();

  // ── Git default header (matches real .git/info/exclude) ──
  const header = [
    "# git ls-files --others --exclude-from=.git/info/exclude",
    "# Lines that start with '#' are comments.",
    "# For a project mostly in C, the following would be a good set of",
    "# exclude patterns (uncomment them if you want to use them):",
    "# *.[oa]",
    "# *~"
  ];

  if (patterns.length === 0) {
    return header.join("\n") + "\n";
  }

  const sections = [];

  patterns.forEach(item => {
    const block = [];
    // Comment line (if any)
    if (item.comment?.trim()) {
      block.push("# " + item.comment.trim());
    }
    // Pattern line (disabled = commented out)
    block.push(item.isEnabled ? item.pattern : "# " + item.pattern);
    sections.push(block.join("\n"));
  });

  // Join: header → blank line → each section separated by blank line → trailing newline
  return header.join("\n") + "\n\n" + sections.join("\n\n") + "\n";
}

function openRawPreview() {
  const repo = state.repositories.find(r => r.id === state.activeTabId);
  const repoPath = repo ? repo.path : "/unknown/repo";
  els.rawPreviewTitle.textContent   = tl("raw.title");
  els.rawPreviewPath.textContent    = repoPath + "/.git/info/exclude";
  els.rawPreviewContent.value       = generateRawContent();
  els.rawPreviewCopyButton.textContent = tl("btn.copy");
  els.rawPreviewDialog.showModal();
}

// ── AI chat helpers ────────────────────────────────────────
function sendMessage() {
  const text = els.chatInput.value.trim();
  if (!text) return;

  if (!state.settings.apiKey.trim()) {
    state.chat.messages.push({ role: "system", content: tl("chat.noApiKey") });
    renderChat();
    return;
  }

  state.chat.messages.push({ role: "user", content: text });
  els.chatInput.value = "";
  state.chat.isTyping = true;
  renderChat();

  setTimeout(() => {
    state.chat.messages.push({ role: "assistant", content: generateMockReply(text) });
    state.chat.isTyping = false;
    renderChat();
  }, 800 + Math.random() * 600);
}

function generateMockReply(msg) {
  const m = msg.toLowerCase();
  if (m.includes("suggest") || m.includes("pattern"))
    return "Here are some common gitignore patterns:\n\n• *.log - Log files\n• node_modules/ - Dependencies\n• .env - Environment variables\n• dist/ or build/ - Build artifacts\n• .DS_Store - macOS files";
  if (m.includes("explain") || m.includes("what"))
    return "Gitignore patterns use glob syntax:\n\n• * matches any string\n• ? matches one character\n• / at end means directory\n• ! negates the pattern\n• # starts a comment";
  if (m.includes("optimize") || m.includes("improve"))
    return "Your patterns look good! Consider:\n\n1. Group related patterns\n2. Add comments for clarity\n3. Use directory patterns (/) for better performance\n4. Keep specific patterns first";
  if (m.includes("hello") || m.includes("hi"))
    return "Hello! I can help you with gitignore patterns. Try asking me to suggest patterns, explain syntax, or optimize your current patterns.";
  return "I understand you're asking about: \"" + msg + "\"\n\nI can help with gitignore patterns, suggestions, and best practices. What would you like to know?";
}

// ── Settings dropdown ──────────────────────────────────────
function toggleDropdown() {
  els.settingsDropdown.classList.toggle("open");
}

function closeDropdown() {
  els.settingsDropdown.classList.remove("open");
}

// ── Theme ──────────────────────────────────────────────────
function applyTheme(theme) {
  state.theme = theme;
  persistTheme(theme);
  if (theme === "system") {
    document.documentElement.removeAttribute("data-theme");
  } else {
    document.documentElement.setAttribute("data-theme", theme);
  }
  // Update active state on buttons
  [els.themeSystem, els.themeLight, els.themeDark].forEach(btn => {
    btn.classList.toggle("active", btn.dataset.themeVal === theme);
  });
}

// ── Auto model/temperature per provider ───────────────────
const AUTO_PROVIDER_CONFIG = {
  openai:    { model: "gpt-4o",          temperature: 0.7 },
  anthropic: { model: "claude-3-5-sonnet-20241022", temperature: 0.7 },
  google:    { model: "gemini-1.5-pro",  temperature: 0.7 },
  other:     { model: "default",         temperature: 0.7 }
};

function getAutoConfig(provider) {
  return AUTO_PROVIDER_CONFIG[provider] || AUTO_PROVIDER_CONFIG.other;
}

// ── AI API Settings dialog ─────────────────────────────────
function openSettings() {
  els.settingsProvider.value = state.settings.provider;
  els.settingsApiKey.value   = state.settings.apiKey;
  updateSettingsAutoNote();
  closeDropdown();
  els.settingsDialog.showModal();
}

function updateSettingsAutoNote() {
  const cfg  = getAutoConfig(els.settingsProvider.value);
  const lang = state.language;
  els.settingsAutoNote.textContent = lang === "th"
    ? `⚡ ระบบจะใช้ ${cfg.model} โดยอัตโนมัติ`
    : `⚡ Model and temperature are set automatically: ${cfg.model}`;
}

function saveSettingsFromForm() {
  state.settings.provider = els.settingsProvider.value;
  state.settings.apiKey   = els.settingsApiKey.value.trim();
  // Auto-apply model & temperature from provider
  const cfg = getAutoConfig(state.settings.provider);
  state.settings.model       = cfg.model;
  state.settings.temperature = cfg.temperature;
  persistSettings(state.settings);
  renderAiStatus();
}

// ── About / Help dialogs ───────────────────────────────────
function openAbout() {
  closeDropdown();
  els.aboutDialog.showModal();
}

function openHelp() {
  closeDropdown();
  els.helpDialog.showModal();
}

// ── Render: AI status badge (dropdown + chat panel) ────────
function renderAiStatus() {
  const ok = state.settings.apiKey.trim().length > 0;
  const label = ok ? tl("ai.configured") : tl("ai.notConfigured");
  const cls   = "badge " + (ok ? "ok" : "warn");
  // Chat panel badge
  els.aiStatusBadge.textContent = label;
  els.aiStatusBadge.className   = cls;
  // Dropdown badge
  els.aiApiStatusBadge.textContent = label;
  els.aiApiStatusBadge.className   = "item-badge " + (ok ? "ok" : "warn");
}

// ── i18n: dropdown labels ──────────────────────────────────
function applyDropdownI18n() {
  const lang = state.language;
  // Language section
  document.getElementById("dropdownLabelLanguage").textContent =
    lang === "th" ? "ภาษา" : "Language";
  document.getElementById("langEnglishLabel").textContent = "English";
  document.getElementById("langThaiLabel").textContent = "ไทย";
  // Appearance section
  document.getElementById("dropdownLabelAppearance").textContent =
    lang === "th" ? "ธีม" : "Appearance";
  document.getElementById("themeSystemLabel").textContent =
    lang === "th" ? "ระบบ" : "System";
  document.getElementById("themeLightLabel").textContent =
    lang === "th" ? "สว่าง" : "Light";
  document.getElementById("themeDarkLabel").textContent =
    lang === "th" ? "มืด" : "Dark";
  document.getElementById("dropdownLabelAiApi").textContent =
    lang === "th" ? "ตั้งค่า AI API" : "AI API Settings";
  document.getElementById("dropdownLabelHelp").textContent =
    lang === "th" ? "วิธีใช้" : "Help";
  document.getElementById("dropdownLabelAbout").textContent =
    lang === "th" ? "เกี่ยวกับ" : "About";
  // About/Help dialog titles
  document.getElementById("aboutTitle").textContent =
    lang === "th" ? "เกี่ยวกับ" : "About";
  document.getElementById("helpTitle").textContent =
    lang === "th" ? "วิธีใช้" : "Help";
  // Help items
  const help = [
    { t: lang === "th" ? "เพิ่ม Pattern" : "Add a Pattern",
      d: lang === "th" ? "คลิก เพิ่ม เพื่อสร้าง pattern ใหม่" : "Click Add to create a new ignore pattern." },
    { t: lang === "th" ? "เปิด / ปิด" : "Enable / Disable",
      d: lang === "th" ? "คลิกวงกลมเพื่อเปิด/ปิด pattern" : "Click the circle toggle to enable or disable a pattern." },
    { t: lang === "th" ? "จัดเรียง" : "Reorder Patterns",
      d: lang === "th" ? "ลาก ⠿ เพื่อจัดเรียง (ปิดขณะค้นหา)" : "Drag the ⠿ handle to reorder. Disabled while searching." },
    { t: lang === "th" ? "ดูไฟล์ต้นฉบับ" : "Preview Raw File",
      d: lang === "th" ? "คลิก 👁 เพื่อดูไฟล์ .git/info/exclude" : "Click 👁 Preview Raw to see the raw file content." },
    { t: lang === "th" ? "AI สร้าง Comment" : "AI Generate Comment",
      d: lang === "th" ? "กรอก pattern แล้วคลิก ✨ AI Generate" : "Enter a pattern and click ✨ AI Generate for a comment." }
  ];
  [1,2,3,4,5].forEach((n, i) => {
    const titleEl = document.getElementById("helpItem" + n + "Title");
    const descEl  = document.getElementById("helpItem" + n + "Desc");
    if (titleEl) titleEl.textContent = help[i].t;
    if (descEl)  descEl.textContent  = help[i].d;
  });
}

// ── Language UI ────────────────────────────────────────────
function updateLanguageUI() {
  [els.langEnglish, els.langThai].forEach(btn => {
    btn.classList.toggle("active", btn.dataset.langVal === state.language);
  });
}

// ── Event listeners ────────────────────────────────────────
[els.langEnglish, els.langThai].forEach(btn => {
  btn.addEventListener("click", () => {
    state.language = btn.dataset.langVal;
    persistLanguage(state.language);
    updateLanguageUI();
    render();
  });
});


els.searchInput.addEventListener("input", ev => {
  state.searchText = ev.target.value;
  renderPatterns();
});

els.clearSearch.addEventListener("click", () => {
  state.searchText = "";
  els.searchInput.value = "";
  renderPatterns();
});

els.patternInput.addEventListener("input", updateGenerateButtonVisibility);

els.generateCommentButton.addEventListener("click", ev => {
  ev.preventDefault();
  generateCommentForPattern();
});

els.addButton.addEventListener("click", () => openEditor(null));

// Editor Cancel button - just close dialog without saving
els.editorCancelButton.addEventListener("click", ev => {
  ev.preventDefault();
  els.dialog.close();
  state.editingId = null;
});

// Editor Save button and form submit - save pattern
els.editorSaveButton.addEventListener("click", ev => {
  ev.preventDefault();
  savePattern();
});

els.editorForm.addEventListener("submit", ev => {
  ev.preventDefault();
  // Only save if it's not a cancel action
  if (ev.submitter && ev.submitter === els.editorSaveButton) {
    savePattern();
  } else {
    els.dialog.close();
    state.editingId = null;
  }
});

els.dialog.addEventListener("close", () => {
  els.dialogError.textContent           = "";
  els.generateCommentButton.hidden      = true;
  els.generateCommentButton.disabled    = false;
  els.generateCommentButton.textContent = tl("btn.generateComment");
  if (els.generateCommentHint) els.generateCommentHint.textContent = "";
  state.editingId = null;
});

els.previewRawButton.addEventListener("click", openRawPreview);

els.rawPreviewCopyButton.addEventListener("click", () => {
  const text = els.rawPreviewContent.value;
  const reset = () => {
    setTimeout(() => { els.rawPreviewCopyButton.textContent = tl("btn.copy"); }, 1500);
  };
  navigator.clipboard.writeText(text).then(() => {
    els.rawPreviewCopyButton.textContent = tl("raw.copied");
    reset();
  }).catch(() => {
    els.rawPreviewContent.select();
    document.execCommand("copy");
    els.rawPreviewCopyButton.textContent = tl("raw.copied");
    reset();
  });
});

els.rawPreviewCloseButton.addEventListener("click", () => els.rawPreviewDialog.close());

// Settings dropdown toggle
els.settingsButton.addEventListener("click", ev => {
  ev.stopPropagation();
  toggleDropdown();
});

// Update auto note when provider changes inside dialog
els.settingsProvider.addEventListener("change", updateSettingsAutoNote);

// Close dropdown when clicking outside
document.addEventListener("click", ev => {
  if (!els.settingsDropdown.contains(ev.target) &&
      ev.target !== els.settingsButton) {
    closeDropdown();
  }
});

// Theme buttons
[els.themeSystem, els.themeLight, els.themeDark].forEach(btn => {
  btn.addEventListener("click", () => applyTheme(btn.dataset.themeVal));
});

// Dropdown menu items
els.openAiSettingsItem.addEventListener("click", openSettings);
els.openAboutItem.addEventListener("click", openAbout);
els.openHelpItem.addEventListener("click", openHelp);

// About / Help close
els.aboutCloseButton.addEventListener("click", () => els.aboutDialog.close());
els.helpCloseButton.addEventListener("click",  () => els.helpDialog.close());

// Cancel button - just close dialog without saving
els.settingsCancelButton.addEventListener("click", ev => {
  ev.preventDefault();
  els.settingsDialog.close();
});

// Save button and form submit - save settings
els.settingsSaveButton.addEventListener("click", ev => {
  ev.preventDefault();
  saveSettingsFromForm();
  els.settingsDialog.close();
});

els.settingsForm.addEventListener("submit", ev => {
  ev.preventDefault();
  // Only save if it's not a cancel action
  if (ev.submitter && ev.submitter === els.settingsSaveButton) {
    saveSettingsFromForm();
  }
  els.settingsDialog.close();
});

els.chatSendButton.addEventListener("click", sendMessage);

els.chatInput.addEventListener("keydown", ev => {
  if (ev.key === "Enter" && !ev.shiftKey) { ev.preventDefault(); sendMessage(); }
});

document.querySelectorAll(".quick-prompt").forEach(btn => {
  btn.addEventListener("click", ev => {
    const map = {
      suggest:  "Suggest common gitignore patterns for this project",
      explain:  "Explain gitignore pattern syntax",
      optimize: "How can I optimize my current patterns?"
    };
    els.chatInput.value = map[ev.target.dataset.prompt] ?? "";
    sendMessage();
  });
});

// ── Open Repository dialog ─────────────────────────────────
function openOpenRepoDialog() {
  const lang = state.language;
  els.openRepoTitle.textContent      = tl("openRepo.title");
  els.openRepoRecentLabel.textContent = lang === "th" ? "ที่เก็บล่าสุด" : "Recent Repositories";
  els.openRepoBrowseButton.textContent = tl("btn.browse");
  els.openRepoCloseButton.textContent  = tl("btn.close");

  const recent = loadRecentRepos();
  els.openRepoList.innerHTML = "";

  if (recent.length === 0) {
    els.openRepoEmpty.hidden      = false;
    els.openRepoEmpty.textContent = lang === "th"
      ? "ยังไม่มีที่เก็บที่เปิดล่าสุด"
      : "No recently opened repositories.";
  } else {
    els.openRepoEmpty.hidden = true;
    recent.forEach(repo => {
      const btn = document.createElement("button");
      btn.className = "open-repo-item" +
        (repo.id === state.activeTabId ? " active" : "");

      const nameEl = document.createElement("div");
      nameEl.className   = "open-repo-item-name";
      nameEl.textContent = repo.name;

      const pathEl = document.createElement("div");
      pathEl.className   = "open-repo-item-path";
      pathEl.textContent = repo.path;

      const timeEl = document.createElement("div");
      timeEl.className   = "open-repo-item-time";
      timeEl.textContent = relativeTime(repo.lastOpened, lang);

      btn.append(nameEl, pathEl, timeEl);
      btn.addEventListener("click", () => {
        if (!state.openRepos[repo.id]) {
          state.openRepos[repo.id] = {
            patterns: MOCK_PATTERNS[repo.id]
              ? [...MOCK_PATTERNS[repo.id].map(p => ({ ...p, id: crypto.randomUUID() }))]
              : [{ id: crypto.randomUUID(), pattern: "*.log", comment: "Log files", isEnabled: true }]
          };
        }
        els.openRepoDialog.close();
        switchTab(repo.id);
      });

      els.openRepoList.appendChild(btn);
    });
  }

  els.openRepoDialog.showModal();
}

// Open Repository button & dialog
els.openRepoButton.addEventListener("click", openOpenRepoDialog);
els.openRepoCloseButton.addEventListener("click", () => els.openRepoDialog.close());
els.openRepoBrowseButton.addEventListener("click", () => {
  els.openRepoDialog.close();
  state.error = tl("error.invalidRepository") + " (mock)";
  els.errorText.textContent = state.error;
});

// ── Boot ───────────────────────────────────────────────────
updateLanguageUI();
applyTheme(state.theme);
const initRepo = state.repositories.find(r => r.id === initialRepoId);
if (initRepo) saveRecentRepo(initRepo);
render();

