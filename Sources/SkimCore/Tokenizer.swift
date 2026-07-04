import Foundation

/// Turns raw text into a stream of `ReadingToken`s (word mode), assigning each
/// a delay multiplier for rhythm, an explicit `Boundary`, and sentence/paragraph
/// indices. Boundaries and indices are cheap to compute now and unlock semantic
/// replay and future phrase chunking. See `docs/tokenizer-spec.md`.
public enum Tokenizer {
    private static let sentenceEnders: Set<Character> = [".", "!", "?", "…"]
    private static let clauseEnders: Set<Character> = [",", ";", ":"]
    private static let closers: Set<Character> = ["\"", "'", "”", "’", "»", ")", "]", "}"]
    private static let openers: Set<Character> = ["\"", "'", "“", "‘", "«", "(", "[", "{"]
    private static let dashes: Set<Character> = ["—", "–"]

    // Title abbreviations: their trailing period never ends a sentence, even
    // before an uppercase word (`Dr. Smith`, `No. 5`). Stored lowercased with
    // the period; the candidate's stripped, lowercased core is matched.
    private static let titles: Set<String> = [
        "mr.", "mrs.", "ms.", "dr.", "prof.", "st.", "sr.", "jr.", "gen.", "sen.",
        "rep.", "gov.", "capt.", "sgt.", "lt.", "col.", "rev.", "hon.", "mt.", "vs.",
        "fig.", "no.", "vol.", "ch.", "sec.", "pp.", "ed.", "cf.",
    ]

    // Context abbreviations: a sentence boundary only when the next word starts
    // with an uppercase letter (`etc. The` breaks; `etc. this` and `Jan. 3` do
    // not). Stored lowercased with the period.
    private static let contextAbbreviations: Set<String> = [
        "etc.", "e.g.", "i.e.", "approx.", "est.", "incl.", "dept.", "inc.", "ltd.",
        "co.", "corp.", "misc.", "al.", "a.m.", "p.m.", "jan.", "feb.", "mar.",
        "apr.", "jun.", "jul.", "aug.", "sep.", "sept.", "oct.", "nov.", "dec.",
    ]

    // Delay multipliers, from the spec's pacing rules.
    private static let longWord = 1.15
    private static let clausePause = 1.4
    private static let sentencePause = 2.0
    private static let paragraphPause = 2.8
    private static let longWordThreshold = 8

    public static func tokenize(_ text: String) -> [ReadingToken] {
        // Clean Markdown first so the reader never shows literal `**`, `#`,
        // backticks, or link URLs.
        let paragraphs = paragraphize(Markdown.strip(text))

        var tokens: [ReadingToken] = []
        var tokenIndex = 0
        var sentenceIndex = 0

        for (paragraphIndex, words) in paragraphs.enumerated() {
            var lastEndedSentence = false

            for (wordIndex, word) in words.enumerated() {
                let isParagraphEnd = wordIndex == words.count - 1
                // One-token lookahead within the paragraph drives the
                // context-abbreviation and ellipsis boundary rules.
                let next: String? = isParagraphEnd ? nil : words[wordIndex + 1]
                let (boundary, multiplier) = classify(word, next: next, isParagraphEnd: isParagraphEnd)

                tokens.append(
                    ReadingToken(
                        text: word,
                        delayMultiplier: multiplier,
                        sentenceIndex: sentenceIndex,
                        paragraphIndex: paragraphIndex,
                        tokenIndex: tokenIndex,
                        boundary: boundary
                    )
                )
                tokenIndex += 1

                // Only a sentence boundary advances inside the loop. A paragraph
                // boundary is counted once by the paragraph transition below, so
                // paragraph-final sentence punctuation is not double-advanced.
                if boundary == .sentence {
                    sentenceIndex += 1
                    lastEndedSentence = true
                } else {
                    lastEndedSentence = false
                }
            }

            // A paragraph break always starts a fresh sentence, even when the
            // paragraph didn't end on terminal punctuation.
            if !lastEndedSentence && !words.isEmpty { sentenceIndex += 1 }
        }

        return tokens
    }

    /// Splits text into paragraphs (arrays of words). Blank lines separate
    /// paragraphs; all other whitespace separates words.
    private static func paragraphize(_ text: String) -> [[String]] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var paragraphs: [[String]] = []
        var current: [String] = []

        for line in normalized.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty { paragraphs.append(current); current = [] }
            } else {
                let words = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
                current.append(contentsOf: words)
            }
        }
        if !current.isEmpty { paragraphs.append(current) }

        return paragraphs
    }

    /// The boundary after `word` and its final delay multiplier. The multiplier
    /// is the maximum of non-boundary effects (long word, complex number) and
    /// the boundary's own pause.
    private static func classify(_ word: String, next: String?, isParagraphEnd: Bool) -> (Boundary, Double) {
        var base = 1.0
        if coreLength(of: word) > longWordThreshold { base = max(base, longWord) }
        if isComplexNumber(word) { base = max(base, longWord) }

        let (boundary, boundaryPause) = classifyBoundary(word, next: next, isParagraphEnd: isParagraphEnd)
        return (boundary, max(base, boundaryPause))
    }

    /// The spec's boundary decision table, evaluated in order; the first match
    /// wins. `next` is the next word in the same paragraph, or nil at the end.
    private static func classifyBoundary(_ word: String, next: String?, isParagraphEnd: Bool) -> (Boundary, Double) {
        let chars = Array(word)
        let core = coreToken(chars)
        let trailing = trailingSignificant(chars)

        // 1. Paragraph-final always wins, even over a title abbreviation.
        if isParagraphEnd { return (.paragraph, paragraphPause) }
        // 2. Closer-skipped `!` or `?`.
        if let c = trailing, c == "!" || c == "?" { return (.sentence, sentencePause) }
        // 3. Initial or acronym (`J.`, `U.S.A.`) — never a sentence boundary.
        if isInitialOrAcronym(core) { return (.none, 1.0) }
        // 4. Title abbreviation — never a sentence boundary.
        if titles.contains(String(core).lowercased()) { return (.none, 1.0) }
        // 5/6. Context abbreviation — sentence only before uppercase prose.
        if contextAbbreviations.contains(String(core).lowercased()) {
            return nextStartsUppercase(next) ? (.sentence, sentencePause) : (.none, 1.0)
        }
        // 7/8. Ellipsis — sentence before uppercase, otherwise clause; always 2.0.
        if isEllipsis(chars) {
            return nextStartsUppercase(next) ? (.sentence, sentencePause) : (.clause, sentencePause)
        }
        // 9. Any other closer-skipped period (ordinary period, terminal decimal).
        if trailing == "." { return (.sentence, sentencePause) }
        // 10. Closer-skipped clause ender.
        if let c = trailing, clauseEnders.contains(c) { return (.clause, clausePause) }
        // 11. Internal em/en dash.
        if hasInternalDash(word) { return (.clause, clausePause) }
        // 12. Otherwise.
        return (.none, 1.0)
    }

    /// The word with any surrounding openers/closers stripped from both ends,
    /// for abbreviation and initial/acronym matching. Never alters display text.
    private static func coreToken(_ chars: [Character]) -> [Character] {
        var c = chars
        while let first = c.first, openers.contains(first) || closers.contains(first) { c.removeFirst() }
        while let last = c.last, openers.contains(last) || closers.contains(last) { c.removeLast() }
        return c
    }

    /// The last character after skipping any trailing run of closing quotes and
    /// brackets (e.g. `pipeline.")` → `.`). Nil when nothing remains.
    private static func trailingSignificant(_ chars: [Character]) -> Character? {
        var i = chars.count - 1
        while i >= 0, closers.contains(chars[i]) { i -= 1 }
        return i >= 0 ? chars[i] : nil
    }

    /// Whether the closer-skipped token ends in an ellipsis: the single `…`, or
    /// a trailing run of two or more periods.
    private static func isEllipsis(_ chars: [Character]) -> Bool {
        var i = chars.count - 1
        while i >= 0, closers.contains(chars[i]) { i -= 1 }
        guard i >= 0 else { return false }
        if chars[i] == "…" { return true }
        var run = 0
        var j = i
        while j >= 0, chars[j] == "." { run += 1; j -= 1 }
        return run >= 2
    }

    /// Whether the stripped core is one or more repetitions of an uppercase
    /// letter followed by a period (`J.`, `U.K.`, `U.S.A.`). Case-sensitive.
    private static func isInitialOrAcronym(_ core: [Character]) -> Bool {
        guard !core.isEmpty, core.count % 2 == 0 else { return false }
        var i = 0
        while i < core.count {
            let letter = core[i]
            guard letter.isLetter, letter.isUppercase else { return false }
            guard core[i + 1] == "." else { return false }
            i += 2
        }
        return true
    }

    /// Whether the next word's first core character, after skipping openers, is
    /// an uppercase letter. A leading digit is not sentence-start evidence.
    private static func nextStartsUppercase(_ next: String?) -> Bool {
        guard let next = next else { return false }
        var chars = Array(next)
        while let first = chars.first, openers.contains(first) { chars.removeFirst() }
        guard let first = chars.first else { return false }
        return first.isLetter && first.isUppercase
    }

    /// Number of letters/digits in a word, ignoring punctuation.
    private static func coreLength(of word: String) -> Int {
        word.reduce(0) { $0 + (($1.isLetter || $1.isNumber) ? 1 : 0) }
    }

    /// Whether the word contains an em-dash or en-dash flanked by word
    /// characters (so "Wait—really" qualifies but a leading/trailing dash does
    /// not). Used to apply a clause pause without splitting the token.
    private static func hasInternalDash(_ word: String) -> Bool {
        let chars = Array(word)
        for i in chars.indices where dashes.contains(chars[i]) {
            let hasLeft = i > 0 && (chars[i - 1].isLetter || chars[i - 1].isNumber)
            let hasRight = i < chars.count - 1 && (chars[i + 1].isLetter || chars[i + 1].isNumber)
            if hasLeft && hasRight { return true }
        }
        return false
    }

    /// Whether a numeric token is visually complex enough to warrant a small
    /// slow-down: it contains a digit plus a separator (`,`/`.`), or has 6+
    /// numeric/separator characters total (e.g. "1,000,000", "3.14159",
    /// "100000", "12.5%"). Tokens without any digit never qualify.
    private static func isComplexNumber(_ word: String) -> Bool {
        var digits = 0
        var separators = 0
        for c in word {
            if c.isNumber { digits += 1 }
            else if c == "," || c == "." { separators += 1 }
        }
        guard digits > 0 else { return false }
        if separators > 0 { return true }
        return (digits + separators) >= 6
    }
}
