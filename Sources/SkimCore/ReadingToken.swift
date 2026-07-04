import Foundation

/// The strongest rhythmic break that follows a token. Explicit so consumers
/// (replay, context, future phrase chunking) never infer pause kind from the
/// numeric `delayMultiplier`. Precedence: paragraph > sentence > clause > none.
public enum Boundary: Sendable, Equatable {
    case none
    case clause
    case sentence
    case paragraph
}

/// A single unit shown on the reading surface, carrying enough metadata to
/// support pacing and (later) semantic replay and context.
public struct ReadingToken: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    /// Scales the base per-token delay. 1.0 is a normal word; punctuation and
    /// paragraph breaks push it higher so the reading gains rhythm.
    public let delayMultiplier: Double
    public let sentenceIndex: Int
    public let paragraphIndex: Int
    public let tokenIndex: Int
    /// The strongest boundary after this token. Defaulted so callers written
    /// before the boundary work continue to compile.
    public let boundary: Boundary

    public init(
        id: UUID = UUID(),
        text: String,
        delayMultiplier: Double,
        sentenceIndex: Int,
        paragraphIndex: Int,
        tokenIndex: Int,
        boundary: Boundary = .none
    ) {
        self.id = id
        self.text = text
        self.delayMultiplier = delayMultiplier
        self.sentenceIndex = sentenceIndex
        self.paragraphIndex = paragraphIndex
        self.tokenIndex = tokenIndex
        self.boundary = boundary
    }
}
