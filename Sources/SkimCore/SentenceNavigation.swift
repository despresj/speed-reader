import Foundation

/// Pure index math for the rail's semantic flicks — the spec's primary recovery
/// action. A back flick replays the sentence you're in; a forward flick skips to
/// the next one. Sibling of `ReadingNavigation` (which keeps the plain word math
/// for the scrubber). Lives in the core so the grace-window and clamping rules
/// are verified by `CoreChecks`, not trusted to the gesture call site.
///
/// Both functions walk `ReadingToken.sentenceIndex` — the metadata the tokenizer
/// has emitted since v1 precisely so this could drop in.
public enum SentenceNavigation {
    /// A back flick within this many tokens of a sentence's start reaches the
    /// *previous* sentence instead: right after a replay (or just as a sentence
    /// opens) "wait, what did that say?" means the one before, not the two words
    /// you just saw.
    public static let graceWindow = 2

    /// The landing index for a back flick at `index`: the first token of the
    /// current sentence, or of the previous sentence when `index` sits inside the
    /// grace window. Clamped — inside the first sentence it bottoms out at 0, and
    /// an empty text is a safe no-op at 0.
    public static func replayTarget(tokens: [ReadingToken], from index: Int) -> Int {
        guard !tokens.isEmpty else { return 0 }
        let i = max(0, min(tokens.count - 1, index))
        let start = sentenceStart(tokens: tokens, at: i)
        if i - start < graceWindow, start > 0 {
            return sentenceStart(tokens: tokens, at: start - 1)
        }
        return start
    }

    /// The landing index for a forward flick at `index`: the first token of the
    /// next sentence. In the last sentence it lands on the final token, so a skip
    /// at the end lets playback run out and complete naturally rather than
    /// teleporting past the finish. Empty text is a safe no-op at 0.
    public static func skipTarget(tokens: [ReadingToken], from index: Int) -> Int {
        guard !tokens.isEmpty else { return 0 }
        let i = max(0, min(tokens.count - 1, index))
        let sentence = tokens[i].sentenceIndex
        var j = i
        while j < tokens.count - 1 {
            j += 1
            if tokens[j].sentenceIndex != sentence { return j }
        }
        return tokens.count - 1
    }

    /// First token index of the sentence containing `index`.
    private static func sentenceStart(tokens: [ReadingToken], at index: Int) -> Int {
        let sentence = tokens[index].sentenceIndex
        var j = index
        while j > 0, tokens[j - 1].sentenceIndex == sentence { j -= 1 }
        return j
    }
}
