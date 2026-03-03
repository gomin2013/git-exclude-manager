/* =============================================================
   shared.js — Shared constants & utilities
   Used by: index.html, main.html
   ============================================================= */

const STORAGE_SETTINGS = "prototype.ai.settings";
const STORAGE_RECENT   = "prototype.recent.repos";
const STORAGE_LANGUAGE = "prototype.language";
const STORAGE_THEME    = "prototype.theme";

// ── Mock repository catalogue ──────────────────────────────
const MOCK_REPOSITORIES = [
  { id: "repo1", name: "git-exclude-manager", path: "/Users/abd-th-012/Documents/SwiftUI/git-exclude-manager" },
  { id: "repo2", name: "MyApp",               path: "/Users/abd-th-012/Projects/MyApp" },
  { id: "repo3", name: "Website",             path: "/Users/abd-th-012/Projects/Website" }
];

const MOCK_PATTERNS = {
  repo1: [
    { id: crypto.randomUUID(), pattern: "*.log",        comment: "Log files",              isEnabled: true  },
    { id: crypto.randomUUID(), pattern: "node_modules/",comment: "NPM dependencies",       isEnabled: true  },
    { id: crypto.randomUUID(), pattern: "build/",       comment: "Build output (disabled)",isEnabled: false },
    { id: crypto.randomUUID(), pattern: ".DS_Store",    comment: "",                       isEnabled: true  }
  ],
  repo2: [
    { id: crypto.randomUUID(), pattern: "*.pyc",         comment: "Python compiled", isEnabled: true },
    { id: crypto.randomUUID(), pattern: "__pycache__/",  comment: "Python cache",    isEnabled: true }
  ],
  repo3: [
    { id: crypto.randomUUID(), pattern: "node_modules/", comment: "Dependencies",   isEnabled: true },
    { id: crypto.randomUUID(), pattern: ".next/",        comment: "Next.js build",  isEnabled: true }
  ]
};

// ── i18n ───────────────────────────────────────────────────
const i18n = {
  en: {
    "window.title":          "Git Exclude Manager",
    "btn.add":               "Add",
    "btn.edit":              "Edit",
    "btn.delete":            "Delete",
    "btn.cancel":            "Cancel",
    "btn.save":              "Save",
    "btn.send":              "Send",
    "btn.browse":            "Browse...",
    "btn.export":            "Export",
    "btn.import":            "Import",
    "btn.settings":          "Settings",
    "btn.open":              "Open",
    "btn.generateComment":   "✨ Generate Comment",
    "hint.generateComment":  "Auto-fill the Comment field based on the pattern name using AI",
    "hint.generateCommentField": "Type a pattern above, then click ✨ Generate Comment to auto-fill",
    "btn.previewRaw":        "Preview Raw",
    "btn.copy":              "Copy",
    "btn.close":             "Close",
    "placeholder.pattern":   "Enter ignore pattern (e.g., *.log)",
    "placeholder.comment":   "Optional comment",
    "placeholder.search":    "Search patterns...",
    "label.pattern":         "Pattern",
    "label.comment":         "Comment",
    "label.repository":      "Repository",
    "label.status":          "Status",
    "label.recentRepos":     "Recent Repositories",
    "label.aiGenerating":    "Generating comment...",
    "message.noPatterns":    "No patterns yet",
    "message.noRecent":      "No recently opened repositories.",
    "status.patternsCount":  "%d patterns (%d enabled)",
    "status.connected":      "Connected",
    "status.noRepository":   "No repository selected",
    "dialog.deleteConfirm":  "Are you sure you want to delete this pattern?",
    "error.invalidPattern":  "Pattern cannot be empty",
    "error.invalidRepository":"Not a valid Git repository",
    "hint.mock":             "Prototype: Add/Edit/Delete/Toggle are mock-only.",
    "hint.reorder":          "Drag rows to reorder (disabled while searching).",
    "chat.title":            "AI Agent",
    "chat.placeholder":      "Ask AI...",
    "chat.welcome":          "👋 Hi! I'm your AI assistant. Ask me about gitignore patterns.",
    "chat.noApiKey":         "⚠️ Please configure AI API in Settings first.",
    "settings.title":        "AI API Settings",
    "settings.provider":     "Provider",
    "settings.apiKey":       "API Key",
    "settings.apiKeyPlaceholder": "sk-...",
    "settings.model":        "Model",
    "settings.modelPlaceholder": "gpt-4",
    "settings.temperature":  "Temperature (0-1)",
    "ai.configured":         "Configured",
    "ai.notConfigured":      "Not Set",
    "raw.title":             "Raw File Preview",
    "raw.copied":            "Copied!",
    "raw.empty":             "# No patterns in this repository yet.",
    "nav.back":              "Repositories",
    "btn.openRepo":          "Open Repository",
    "openRepo.title":        "Open Repository"
  },
  th: {
    "window.title":          "Git Exclude Manager",
    "btn.add":               "เพิ่ม",
    "btn.edit":              "แก้ไข",
    "btn.delete":            "ลบ",
    "btn.cancel":            "ยกเลิก",
    "btn.save":              "บันทึก",
    "btn.send":              "ส่ง",
    "btn.browse":            "เรียกดู...",
    "btn.export":            "ส่งออก",
    "btn.import":            "นำเข้า",
    "btn.settings":          "การตั้งค่า",
    "btn.open":              "เปิด",
    "btn.generateComment":   "✨ สร้าง Comment",
    "hint.generateComment":  "AI จะสร้างข้อความ Comment ให้อัตโนมัติจากชื่อ Pattern",
    "hint.generateCommentField": "กรอก Pattern แล้วกด ✨ สร้าง Comment เพื่อให้ AI สร้างให้",
    "btn.previewRaw":        "ดูไฟล์ต้นฉบับ",
    "btn.copy":              "คัดลอก",
    "btn.close":             "ปิด",
    "placeholder.pattern":   "ป้อนรูปแบบการละเว้น (เช่น *.log)",
    "placeholder.comment":   "ความเห็นเพิ่มเติม (ไม่บังคับ)",
    "placeholder.search":    "ค้นหารูปแบบ...",
    "label.pattern":         "รูปแบบ",
    "label.comment":         "ความเห็น",
    "label.repository":      "ที่เก็บ",
    "label.status":          "สถานะ",
    "label.recentRepos":     "ที่เก็บล่าสุด",
    "label.aiGenerating":    "กำลังสร้าง Comment...",
    "message.noPatterns":    "ยังไม่มีรูปแบบ",
    "message.noRecent":      "ยังไม่มีที่เก็บที่เปิดล่าสุด",
    "status.patternsCount":  "%d รูปแบบ (%d เปิดใช้งาน)",
    "status.connected":      "เชื่อมต่ออยู่",
    "status.noRepository":   "ไม่ได้เลือกที่เก็บ",
    "dialog.deleteConfirm":  "คุณต้องการลบรูปแบบนี้หรือไม่",
    "error.invalidPattern":  "รูปแบบไม่สามารถว่างเปล่าได้",
    "error.invalidRepository":"ไม่ใช่ที่เก็บ Git ที่ถูกต้อง",
    "hint.mock":             "ต้นแบบ: การเพิ่ม/แก้ไข/ลบ/สลับ เป็นข้อมูลจำลอง",
    "hint.reorder":          "ลากแถวเพื่อจัดเรียงใหม่ (ปิดไว้ระหว่างค้นหา)",
    "chat.title":            "AI ผู้ช่วย",
    "chat.placeholder":      "ถาม AI...",
    "chat.welcome":          "👋 สวัสดี! ฉันคือผู้ช่วย AI ถามฉันเกี่ยวกับ gitignore ได้เลย",
    "chat.noApiKey":         "⚠️ กรุณาตั้งค่า AI API ในการตั้งค่าก่อน",
    "settings.title":        "การตั้งค่า AI API",
    "settings.provider":     "ผู้ให้บริการ",
    "settings.apiKey":       "API Key",
    "settings.apiKeyPlaceholder": "sk-...",
    "settings.model":        "โมเดล",
    "settings.modelPlaceholder": "gpt-4",
    "settings.temperature":  "Temperature (0-1)",
    "ai.configured":         "ตั้งค่าแล้ว",
    "ai.notConfigured":      "ยังไม่ตั้งค่า",
    "raw.title":             "ดูไฟล์ต้นฉบับ",
    "raw.copied":            "คัดลอกแล้ว!",
    "raw.empty":             "# ยังไม่มีรูปแบบในที่เก็บนี้",
    "nav.back":              "ที่เก็บ",
    "btn.openRepo":          "เปิด Repository",
    "openRepo.title":        "เปิด Repository"
  }
};

// ── Translation helper ─────────────────────────────────────
function t(key, lang) {
  const l = lang || (typeof appLang !== "undefined" ? appLang() : "en");
  return i18n[l]?.[key] ?? key;
}

// ── Settings persistence ───────────────────────────────────
function loadStoredSettings(defaults) {
  try {
    const raw = window.localStorage.getItem(STORAGE_SETTINGS);
    if (!raw) return defaults;
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return defaults;
    return {
      provider: String(parsed.provider || defaults.provider || "openai"),
      apiKey:   String(parsed.apiKey   || "")
    };
  } catch { return defaults; }
}

function persistSettings(settings) {
  try {
    window.localStorage.setItem(STORAGE_SETTINGS, JSON.stringify(settings));
  } catch { /* ignore */ }
}

// ── Recent repositories ────────────────────────────────────
function loadRecentRepos() {
  try {
    const raw = window.localStorage.getItem(STORAGE_RECENT);
    return raw ? JSON.parse(raw) : [];
  } catch { return []; }
}

function saveRecentRepo(repo) {
  try {
    let recent = loadRecentRepos().filter(r => r.id !== repo.id);
    recent.unshift({ id: repo.id, name: repo.name, path: repo.path, lastOpened: Date.now() });
    if (recent.length > 10) recent = recent.slice(0, 10);
    window.localStorage.setItem(STORAGE_RECENT, JSON.stringify(recent));
  } catch { /* ignore */ }
}

// ── Language persistence ───────────────────────────────────
function loadStoredLanguage() {
  return window.localStorage.getItem(STORAGE_LANGUAGE) || "en";
}

function persistLanguage(lang) {
  window.localStorage.setItem(STORAGE_LANGUAGE, lang);
}

// ── Theme persistence ──────────────────────────────────────
function loadStoredTheme() {
  return window.localStorage.getItem(STORAGE_THEME) || "system";
}

function persistTheme(theme) {
  window.localStorage.setItem(STORAGE_THEME, theme);
}

// ── Relative time ──────────────────────────────────────────
function relativeTime(ts, lang) {
  const diff = Date.now() - ts;
  const mins  = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days  = Math.floor(diff / 86400000);
  if (lang === "th") {
    if (mins  < 1)   return "เมื่อกี้";
    if (mins  < 60)  return mins  + " นาทีที่แล้ว";
    if (hours < 24)  return hours + " ชั่วโมงที่แล้ว";
    return days + " วันที่แล้ว";
  }
  if (mins  < 1)   return "just now";
  if (mins  < 60)  return mins  + "m ago";
  if (hours < 24)  return hours + "h ago";
  return days + "d ago";
}
