#!/bin/bash
# Website / README screenshots from the app's -demo mode (steering: never real repository paths).
# Brings each window to the front for ~10 s — don't type while it runs (~2 min, ~4 min with --ai).
# Usage: scripts/capture-screenshots.sh [--ai]
#   --ai  also the AI Agent answer: debug build (-ask) + your configured AI provider; rebuilds release after.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/GitExcludeManager.app"
IMG="$ROOT/docs/assets/img"
TMP="$(mktemp -d)"
DEMO_UI=com.gitexcludemanager.demo-ui   # the demo's own UI settings (DemoData.defaults), never the real ones
trap 'rm -rf "$TMP"; pkill -f "$APP/Contents/MacOS/GitExcludeManager" || true; defaults delete $DEMO_UI 2>/dev/null || true' EXIT

# Window ID of the app's main window (screencapture -l keeps the rounded corners transparent)
cat > "$TMP/winid.swift" <<'EOF'
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowOwnerName as String] as? String) == "Git Exclude Manager"
    && (w[kCGWindowLayer as String] as? Int) == 0
    && ((w[kCGWindowBounds as String] as? [String: Any])?["Width"] as? Double ?? 0) > 600 {
    print(w[kCGWindowNumber as String]!); break
}
EOF
swiftc -O "$TMP/winid.swift" -o "$TMP/winid"

# shot <name> <seconds to wait> <side panel> [extra app args]
# Settings go through `defaults write`: the bundled app opens no window when launched with a bare value argument
# (`-ui.toolPanel history`), so only single-token flags are passed (`-demo`, `-ask=…`).
shot() {
    local name=$1 wait=$2 panel=$3; shift 3
    pkill -f "$APP/Contents/MacOS/GitExcludeManager" || true
    sleep 1.5
    defaults write $DEMO_UI ui.toolPanel "$panel"
    defaults write $DEMO_UI app.language en
    open -n "$APP" --args -demo "$@"
    sleep 5
    # -demo sizes its own window to 1100×800 (DemoData.seed); moving it from here needs Accessibility access
    osascript -e 'tell application id "com.gitexcludemanager.app" to activate'
    sleep "$wait"
    screencapture -x -o -l"$("$TMP/winid")" "$TMP/$name.png"
    echo "captured $name"
}

"$ROOT/scripts/build-app.sh" >/dev/null   # release, current source
shot main 2 agent
shot history 2 history
shot clipboard 2 clipboard
shot suggestions 2 suggestions

# Crops (1100×800 window, no toolbar: side panel x 747…1047 from y 42; Editors section from y 210)
cp "$TMP/main.png" "$IMG/gem-main.png"
cp "$TMP/main.png" "$ROOT/docs/images/screenshot.png"
sips -c 440 736 --cropOffset 210 0 "$TMP/main.png" --out "$IMG/gem-sections.png" >/dev/null
sips -c 290 300 --cropOffset 42 747 "$TMP/history.png" --out "$IMG/gem-history.png" >/dev/null
sips -c 175 300 --cropOffset 42 747 "$TMP/clipboard.png" --out "$TMP/clip.png" >/dev/null
sips -c 260 300 --cropOffset 42 747 "$TMP/suggestions.png" --out "$TMP/sugg.png" >/dev/null
cat > "$TMP/stack.swift" <<'EOF'
import AppKit
// Stacks PNGs vertically with a 10 px transparent gap.
let images = CommandLine.arguments.dropFirst(2).map { NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: $0)))! }
let width = images.map(\.pixelsWide).max()!, height = images.reduce(0) { $0 + $1.pixelsHigh } + 10 * (images.count - 1)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
var y = height
for image in images {
    y -= image.pixelsHigh
    image.draw(in: NSRect(x: 0, y: y, width: image.pixelsWide, height: image.pixelsHigh)); y -= 10
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
EOF
swiftc -O "$TMP/stack.swift" -o "$TMP/stack"
"$TMP/stack" "$IMG/gem-suggestions.png" "$TMP/clip.png" "$TMP/sugg.png"

if [ "${1:-}" = "--ai" ]; then
    "$ROOT/scripts/build-app.sh" debug >/dev/null
    # Uses your configured AI provider (the demo doesn't change AI settings) — Ollama qwen3.8 takes ~90 s
    shot ai 110 agent \
        "-ask=Suggest 3 more patterns this repository should ignore: a gitignore code block with only the patterns (no comments, it must fit a narrow panel), then a bullet list with one short reason per pattern."
    sips -c 748 300 --cropOffset 42 747 "$TMP/ai.png" --out "$IMG/gem-ai-panel.png" >/dev/null
    "$ROOT/scripts/build-app.sh" >/dev/null   # back to release
fi

swift "$ROOT/scripts/make-og-image.swift"   # social card uses the new gem-main.png
echo "Updated: $(cd "$ROOT" && git status --short docs/ | tr '\n' ' ')"
