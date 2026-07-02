import Foundation

/// The re-entry ease: after a real pause, playback resumes a few words back and
/// the first tokens run slightly slow, decaying to full pace — so re-engaging
/// never feels like being dropped into moving traffic. Felt, not shown: unlike
/// `SpeedRamp` this never touches the speed band, so the gauge stays put. The
/// curve is a smoothstep decay over whole tokens (the unit the playback loop
/// actually advances by), multiplied into `Pacing.secondsPerToken`.
///
/// Pure and UI-free so `CoreChecks` can pin the threshold, the curve shape, and
/// the exact settle point without a device.
public struct ResumeGlide: Equatable, Sendable {
    /// A brake shorter than this is a quick tap-pause-tap — resume instantly,
    /// no back-step, no ease, so the glide never fights a user who barely left.
    public static let pauseThreshold: Double = 2.0
    /// How many words a real resume steps back, onto prose already read.
    public static let backStepWords = 3
    /// How many tokens the ease spans before pacing is exactly normal again.
    public static let easeSpan = 8
    /// The delay multiplier on the very first token after resume.
    public static let peakMultiplier = 1.6

    /// Words to step back before resuming (0 for a landing ease, where the
    /// user's flick already chose the position).
    public let backStep: Int
    public let span: Int
    public let peak: Double

    public init(backStep: Int, span: Int, peak: Double) {
        self.backStep = backStep
        self.span = span
        self.peak = peak
    }

    /// The glide for resuming after a pause of `pauseDuration` seconds — or
    /// `nil` below the threshold, where resume should be instant.
    public static func plan(pauseDuration: Double) -> ResumeGlide? {
        guard pauseDuration >= pauseThreshold else { return nil }
        return ResumeGlide(backStep: backStepWords, span: easeSpan, peak: peakMultiplier)
    }

    /// The ease-only glide for a backward replay flick while playing: the flick
    /// chose the landing spot, so no back-step — just the soft landing.
    public static func landing() -> ResumeGlide {
        ResumeGlide(backStep: 0, span: easeSpan, peak: peakMultiplier)
    }

    /// Extra pacing multiplier for the `k`-th token after resume (0-based).
    /// `peak` at token 0, smoothstep-decaying to exactly 1.0 at `span` and
    /// beyond — monotonically non-increasing, so pacing only ever settles.
    public func multiplier(atToken k: Int) -> Double {
        guard span > 0, k < span else { return 1 }
        guard k > 0 else { return peak }
        let t = Double(k) / Double(span)
        let eased = t * t * (3 - 2 * t)
        return peak + (1 - peak) * eased
    }
}
