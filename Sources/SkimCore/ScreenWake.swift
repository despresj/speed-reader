import Foundation

/// Whether the phone's screen must stay awake for a given reader state. This is
/// the *decision* only — the view model applies the UIKit side effect
/// (`isIdleTimerDisabled`) whenever the state changes. Both directions matter
/// equally: letting the screen sleep mid-cruise breaks the "carried" promise,
/// and *failing to restore* the idle timer on pause is just as bad — a parked
/// app must never hold the screen hostage.
public enum ScreenWake {
    /// True only while words are actually advancing. Exhaustive on purpose —
    /// a future `ReaderState` case must decide its wake behavior here at
    /// compile time rather than silently inheriting one.
    public static func shouldStayAwake(_ state: ReaderState) -> Bool {
        switch state {
        case .precisionHeld, .cruisePlaying:
            return true
        case .idle, .ready, .paused, .completed:
            return false
        }
    }
}
