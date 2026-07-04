import Foundation

/// A single change cleanup made, kept so the result is inspectable.
public enum CleanupOperationKind: Sendable, Equatable {
    case normalizeWhitespace
    case collapseBlankLines
    case repairWrappedLines
    case removeBracketCitation
    case removeStandaloneUrl
    case collapseInlineUrl
    case removeHtmlEntity
    case removeBoilerplateLine
    case removeCookiePrompt
    case removeShareNavigation
    case removeImageCaption
    case removeInvisible
    case normalizeQuotes
    case normalizeDashes
    case preserve
}

public struct CleanupOperation: Sendable, Equatable {
    public let kind: CleanupOperationKind
    public let original: String
    public let replacement: String
    public let reason: String
    public init(kind: CleanupOperationKind, original: String, replacement: String, reason: String) {
        self.kind = kind
        self.original = original
        self.replacement = replacement
        self.reason = reason
    }
}

public struct CleanupWarning: Sendable, Equatable {
    public let message: String
    public init(message: String) { self.message = message }
}

public struct CleanedText: Sendable, Equatable {
    public let text: String
    public let operations: [CleanupOperation]
    public let warnings: [CleanupWarning]
    public init(text: String, operations: [CleanupOperation], warnings: [CleanupWarning]) {
        self.text = text
        self.operations = operations
        self.warnings = warnings
    }
}

/// Normalizes pasted/shared text into clean reader input without rewriting
/// prose. Deterministic and idempotent. Runs after `Markdown.strip` and before
/// `Tokenizer.tokenize`. See `docs/text-cleanup-spec.md`.
public enum TextCleanup {
    private static let openers: Set<Character> = ["\"", "'", "“", "‘", "«", "(", "[", "{"]
    private static let closers: Set<Character> = ["\"", "'", "”", "’", "»", ")", "]", "}"]

    // Whole-line, lowercased frozen match sets. A line is removed only when its
    // entire trimmed content matches; the same words inside prose are preserved.
    private static let boilerplate: Set<String> = [
        "subscribe to our newsletter", "sign up for our newsletter", "advertisement",
        "sponsored content", "continue reading", "read more", "share this article",
        "back to top", "all rights reserved", "privacy policy", "terms of service",
    ]
    private static let cookiePrompts: Set<String> = [
        "accept all cookies", "reject all", "manage preferences", "manage consent",
        "cookie settings", "we use cookies to improve your experience",
    ]
    private static let shareNavigation: Set<String> = [
        "facebook", "twitter", "linkedin", "copy link", "share", "menu",
        "search", "home", "skip to content",
    ]

    public static func clean(_ input: String) -> CleanedText {
        var ops: [CleanupOperation] = []
        var text = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        text = stripInvisible(text, &ops)
        text = decodeEntities(text, &ops)
        text = removeDebrisLines(text, &ops)
        text = removeCitations(text, &ops)
        text = collapseInlineURLs(text, &ops)
        text = repairWraps(text, &ops)
        text = normalizeWhitespacePerLine(text, &ops)
        text = collapseBlankLines(text, &ops)

        return CleanedText(text: text, operations: ops, warnings: [])
    }

    // MARK: - Invisible characters and entities

    private static func stripInvisible(_ text: String, _ ops: inout [CleanupOperation]) -> String {
        var out = text
        for (bad, repl) in [("\u{200B}", ""), ("\u{00AD}", ""), ("\u{FEFF}", ""), ("\u{00A0}", " ")] {
            out = out.replacingOccurrences(of: bad, with: repl)
        }
        if out != text {
            ops.append(.init(kind: .removeInvisible, original: text, replacement: out,
                             reason: "stripped invisible/control characters"))
        }
        return out
    }

    private static func decodeEntities(_ text: String, _ ops: inout [CleanupOperation]) -> String {
        var out = text
        // `&amp;` first so a partially double-encoded entity resolves consistently.
        for (entity, repl) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
                               ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " ")] {
            out = out.replacingOccurrences(of: entity, with: repl)
        }
        if out != text {
            ops.append(.init(kind: .removeHtmlEntity, original: text, replacement: out,
                             reason: "decoded HTML entities"))
        }
        return out
    }

    // MARK: - Line-level removals

    private static func removeDebrisLines(_ text: String, _ ops: inout [CleanupOperation]) -> String {
        var kept: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if !trimmed.isEmpty {
                if isStandaloneURL(trimmed) {
                    ops.append(.init(kind: .removeStandaloneUrl, original: line, replacement: "",
                                     reason: "line was a standalone URL")); continue
                }
                if boilerplate.contains(lower) {
                    ops.append(.init(kind: .removeBoilerplateLine, original: line, replacement: "",
                                     reason: "line matched frozen boilerplate")); continue
                }
                if cookiePrompts.contains(lower) {
                    ops.append(.init(kind: .removeCookiePrompt, original: line, replacement: "",
                                     reason: "line was a cookie prompt")); continue
                }
                if shareNavigation.contains(lower) {
                    ops.append(.init(kind: .removeShareNavigation, original: line, replacement: "",
                                     reason: "line was share/navigation debris")); continue
                }
                if isCaption(trimmed) {
                    ops.append(.init(kind: .removeImageCaption, original: line, replacement: "",
                                     reason: "line was an image caption")); continue
                }
            }
            kept.append(line)
        }
        return kept.joined(separator: "\n")
    }

    private static func isStandaloneURL(_ trimmed: String) -> Bool {
        var s = trimmed
        if s.hasPrefix("<") && s.hasSuffix(">") { s = String(s.dropFirst().dropLast()) }
        guard !s.contains(where: { $0.isWhitespace }) else { return false }
        let lower = s.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.")
    }

    private static func isCaption(_ trimmed: String) -> Bool {
        matches(#"^(image|photo|caption|figure)( [0-9]+)?:"#, in: trimmed, caseInsensitive: true)
    }

    // MARK: - Inline substitutions

    private static func removeCitations(_ text: String, _ ops: inout [CleanupOperation]) -> String {
        let (out, changed) = regexReplace(#"[ \t]*(\[[0-9]+([ \t]*,[ \t]*[0-9]+)*\])+"#, in: text, with: "")
        if changed {
            ops.append(.init(kind: .removeBracketCitation, original: text, replacement: out,
                             reason: "removed bracketed numeric citations"))
        }
        return out
    }

    private static func collapseInlineURLs(_ text: String, _ ops: inout [CleanupOperation]) -> String {
        let (out, changed) = regexReplace(#"(https?://|www\.)\S+"#, in: text, with: "[link]")
        if changed {
            ops.append(.init(kind: .collapseInlineUrl, original: text, replacement: out,
                             reason: "replaced inline URLs with [link]"))
        }
        return out
    }

    // MARK: - Wrapped-line repair

    private static func repairWraps(_ text: String, _ ops: inout [CleanupOperation]) -> String {
        var out: [String] = []
        var joined = false
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                out.append(line); continue
            }
            if let last = out.last,
               !last.trimmingCharacters(in: .whitespaces).isEmpty,
               canJoin(previous: last, current: line) {
                out[out.count - 1] = last + " " + line.trimmingCharacters(in: .whitespaces)
                joined = true
            } else {
                out.append(line)
            }
        }
        let result = out.joined(separator: "\n")
        if joined {
            ops.append(.init(kind: .repairWrappedLines, original: text, replacement: result,
                             reason: "joined lowercase-continuation wrapped lines"))
        }
        return result
    }

    /// Join only a confident soft wrap: the continuation begins lowercase, the
    /// previous line has no terminal punctuation, and neither line is a list.
    private static func canJoin(previous: String, current: String) -> Bool {
        let p = previous.trimmingCharacters(in: .whitespaces)
        let c = current.trimmingCharacters(in: .whitespaces)
        if isListLike(p) || isListLike(c) { return false }
        if endsTerminal(p) { return false }
        return startsLowercaseLetter(c)
    }

    private static func isListLike(_ s: String) -> Bool {
        if s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("• ") { return true }
        var idx = s.startIndex
        var sawDigit = false
        while idx < s.endIndex, s[idx].isNumber { sawDigit = true; idx = s.index(after: idx) }
        if sawDigit, idx < s.endIndex, s[idx] == "." || s[idx] == ")" {
            let next = s.index(after: idx)
            return next == s.endIndex || s[next] == " "
        }
        return false
    }

    private static func endsTerminal(_ s: String) -> Bool {
        let chars = Array(s)
        var i = chars.count - 1
        while i >= 0, closers.contains(chars[i]) { i -= 1 }
        guard i >= 0 else { return false }
        let c = chars[i]
        return c == "." || c == "!" || c == "?" || c == "…" || c == ":"
    }

    private static func startsLowercaseLetter(_ s: String) -> Bool {
        var chars = Array(s)
        while let f = chars.first, openers.contains(f) { chars.removeFirst() }
        guard let f = chars.first else { return false }
        return f.isLetter && f.isLowercase
    }

    // MARK: - Whitespace

    private static func normalizeWhitespacePerLine(_ text: String, _ ops: inout [CleanupOperation]) -> String {
        var changed = false
        let out = text.components(separatedBy: "\n").map { line -> String in
            let collapsed = regexReplace(#"[ \t]+"#, in: line, with: " ").0
                .trimmingCharacters(in: .whitespaces)
            if collapsed != line { changed = true }
            return collapsed
        }
        let joined = out.joined(separator: "\n")
        if changed {
            ops.append(.init(kind: .normalizeWhitespace, original: text, replacement: joined,
                             reason: "collapsed horizontal whitespace and trimmed line edges"))
        }
        return joined
    }

    private static func collapseBlankLines(_ text: String, _ ops: inout [CleanupOperation]) -> String {
        let collapsed = regexReplace(#"\n{3,}"#, in: text, with: "\n\n").0
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != text {
            ops.append(.init(kind: .collapseBlankLines, original: text, replacement: trimmed,
                             reason: "collapsed blank-line runs and trimmed document edges"))
        }
        return trimmed
    }

    // MARK: - Regex helpers

    private static func regexReplace(_ pattern: String, in text: String, with template: String) -> (String, Bool) {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return (text, false) }
        let range = NSRange(text.startIndex..., in: text)
        let out = re.stringByReplacingMatches(in: text, range: range, withTemplate: template)
        return (out, out != text)
    }

    private static func matches(_ pattern: String, in text: String, caseInsensitive: Bool) -> Bool {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return re.firstMatch(in: text, range: range) != nil
    }
}
