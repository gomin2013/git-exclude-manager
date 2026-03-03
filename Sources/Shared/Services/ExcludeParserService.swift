import Foundation

/// Parses `.git/info/exclude` text into `GitExcludePattern` values.
public enum ExcludeParserService {
    // MARK: - Public Interface

    public static func parseItems(data: Data) throws -> [GitExcludePattern] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw HelperError.invalidData("Unable to decode file as UTF-8")
        }
        return parseItems(content: content)
    }

    /// Pattern items only (no sections/comments).
    public static func parse(content: String) -> [GitExcludePattern] {
        parseItems(content: content).filter { $0.kind == .pattern }
    }

    /// Parses every line into an item, losslessly: `serialize(parseItems(x)) == x` (modulo a missing final newline).
    /// - `""` → section; a directly following `# heading` line becomes its title
    /// - pattern / `#pattern` → pattern item
    /// - anything else → comment item (consecutive lines grouped)
    public static func parseItems(content: String) -> [GitExcludePattern] {
        var lines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        if lines.last == "" { lines.removeLast() }  // final newline, not a blank line

        var items: [GitExcludePattern] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            index += 1
            if line.isEmpty {
                var title = ""
                if index < lines.count, lines[index].hasPrefix("# "), parseLine(lines[index]) == nil {
                    title = String(lines[index].dropFirst(2))
                    index += 1
                }
                items.append(GitExcludePattern(pattern: title, kind: .section))
            } else if let pattern = parseLine(line) {
                items.append(pattern)
            } else if let last = items.last, last.kind == .comment {
                items[items.count - 1].pattern += "\n" + line
            } else {
                items.append(GitExcludePattern(pattern: line, kind: .comment))
            }
        }
        return items
    }

    /// Serializes items back to `.git/info/exclude` text.
    public static func serialize(_ items: [GitExcludePattern]) -> String {
        let lines = items.flatMap(\.linesInFile)
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private Methods

    private static func parseLine(_ line: String) -> GitExcludePattern? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }

        // `#pattern` (no space) = disabled pattern; `# text` or bare `#` = plain comment.
        if trimmed.hasPrefix("#") {
            let rest = trimmed.dropFirst()
            guard let first = rest.first, !first.isWhitespace else {
                return nil
            }
            return buildPattern(from: String(rest), isEnabled: false)
        }

        return buildPattern(from: trimmed, isEnabled: true)
    }

    private static func buildPattern(
        from source: String,
        isEnabled: Bool
    ) -> GitExcludePattern? {
        let parts = splitPatternAndComment(source)
        let patternValue = parts.pattern.trimmingCharacters(in: .whitespaces)

        guard isLikelyPattern(patternValue) else {
            return nil
        }

        let commentValue = parts.comment?.trimmingCharacters(in: .whitespaces)
        let normalizedComment = commentValue?.isEmpty == true ? nil : commentValue

        return GitExcludePattern(
            pattern: patternValue,
            isEnabled: isEnabled,
            comment: normalizedComment
        )
    }

    private static func splitPatternAndComment(_ line: String) -> (pattern: String, comment: String?) {
        guard let range = line.range(of: " # ") else {
            return (line, nil)
        }

        let pattern = String(line[..<range.lowerBound])
        let comment = String(line[range.upperBound...])
        return (pattern, comment)
    }

    private static func isLikelyPattern(_ value: String) -> Bool {
        guard !value.isEmpty else {
            return false
        }

        if value.contains(" ") {
            let knownMarkers = ["*", "?", "[", "]", "/", ".", "!"]
            return knownMarkers.contains { marker in value.contains(marker) }
        }

        return true
    }
}
