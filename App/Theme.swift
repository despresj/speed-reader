import SwiftUI
import UIKit

/// Crisp, system-aware palette resolved through the selected theme
/// (`SkimTheme.current`, set in Settings). Every role keeps a light and a dark
/// variant — the system appearance decides which renders — and every theme keeps
/// the one accent "thread" reserved for your place in the text (pivot letter,
/// progress thread, active-word highlight), with light-mode accents deep enough
/// that white-on-accent meets AA. Computed (not stored) so a theme change takes
/// effect on the next render — `ContentView` keys the surface on the theme to
/// force that render.
extension Color {
    /// Base canvas. A `readingCanvas` gradient is layered on top for depth.
    static var readingBackground: Color { themed(\.background) }

    /// Slightly lifted surface for cards and inputs.
    static var readingSurface: Color { themed(\.surface) }

    /// Hairline separators / borders — theme-neutral by design.
    static let readingBorder = dynamic(
        dark:  UIColor(white: 1.0, alpha: 0.10),
        light: UIColor(white: 0.0, alpha: 0.08)
    )

    /// Primary text. Off-white in dark to cut glare; deep ink, never pure black,
    /// in light.
    static var readingForeground: Color { themed(\.foreground) }

    /// De-emphasized text — hints, placeholders, secondary labels.
    static var readingMuted: Color { themed(\.muted) }

    /// The thread: the theme's one vivid accent.
    static var readingAccent: Color { themed(\.accent) }

    /// Color for text/icons sitting on top of the accent fill.
    static var readingOnAccent: Color { themed(\.onAccent) }

    /// The pivot ("optimal recognition point") letter that holds your eye on a
    /// fixed spot as words flash past — the thread stitched through the word.
    /// Same accent as `readingAccent` so the reading surface speaks one
    /// color language.
    static var readingPivot: Color { themed(\.accent) }

    /// The hot end of the speed ramp: the thread heats toward the theme's
    /// energized endpoint at full speed. Same family as `readingAccent` so the
    /// surface keeps one color language — energy, not alarm.
    static var readingAccentHot: Color { themed(\.accentHot) }

    /// The faint lift at the top of the full-bleed canvas gradient.
    static var readingCanvasTop: Color { themed(\.canvasTop) }

    /// Resolve one palette role of the *current* theme into a trait-dynamic Color.
    private static func themed(_ role: KeyPath<ThemePalette, ThemePalette.Pair>) -> Color {
        let pair = SkimTheme.current.palette[keyPath: role]
        return dynamic(dark: pair.dark, light: pair.light)
    }

    /// The accent warmed toward `readingAccentHot` by `warmth` (0…1). At rest it's
    /// the calm vermillion; at a blast it's the hotter orange.
    static func readingAccent(warmth: Double) -> Color {
        lerp(.readingAccent, .readingAccentHot, warmth)
    }

    /// The pivot letter warmed the same way, so the focal ORP letter heats with
    /// pace alongside the rest of the accent family.
    static func readingPivot(warmth: Double) -> Color {
        lerp(.readingPivot, .readingAccentHot, warmth)
    }

    /// Blend two colors by `amount` (clamped 0…1). Resolves each endpoint per
    /// trait, so dynamic light/dark colors interpolate correctly in either scheme.
    static func lerp(_ from: Color, _ to: Color, _ amount: Double) -> Color {
        let a = CGFloat(min(1, max(0, amount)))
        let f = UIColor(from)
        let t = UIColor(to)
        return Color(uiColor: UIColor { trait in
            let fc = f.resolvedColor(with: trait)
            let tc = t.resolvedColor(with: trait)
            var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
            var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
            fc.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
            tc.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
            return UIColor(red:   fr + (tr - fr) * a,
                           green: fg + (tg - fg) * a,
                           blue:  fb + (tb - fb) * a,
                           alpha: fa + (ta - fa) * a)
        })
    }

    private static func dynamic(dark: UIColor, light: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// Speed-responsive warmth: a tight vermillion *instrument aura* that gently lights
/// the speed gauge in the reading-hand corner and fades fast into the dark canvas — a
/// localized glow that belongs to the gauge, not a side panel or an edge wash. Its
/// hue rides the speed (muted vermillion cruising → hotter orange at a blast) and it
/// swells a little as the band climbs; it stays subtle while actively reading and a
/// touch more present when paused or while the dial is being turned.
///
/// Two layers, back to front, so the warmth frames the word instead of competing:
///   1. A subtle vignette that lets the edges settle into ink, deepening the
///      middle and keeping the focal word in a clean, dark pocket.
///   2. A tight aura centered on the gauge — radius only modestly past the
///      instrument, opacity front-loaded so it's nearly gone before the center word.
/// Layered above the base `ReadingCanvas`; the deep background still dominates and
/// the main word keeps its contrast (the glow lives away from it; the vignette only
/// darkens behind it).
struct ReadingWarmth: View {
    let warmth: Double
    let leftHanded: Bool
    /// Halo energy (0…1) for the reader's mode: parked is a faint hint, a held thumb
    /// is medium, cruise is strongest. It scales the glow's *brightness*, never its
    /// footprint — an active read makes the instrument burn warmer, not wider, so the
    /// right side never lights up as a panel. Defaults to the calm parked level.
    var intensity: Double = 0.4

    var body: some View {
        // Hue rides the speed, in the same vermillion family as the gauge: muted
        // while cruising, heating toward orange at a blast — energy, not alarm.
        let hue = Color.readingAccent(warmth: warmth)

        // The gauge sits at mid-height hugging the reading-hand edge. The halo is
        // measured in *points* off that fixed anchor (not screen fractions), so its
        // size never grows with the screen — it stays a glow on the instrument.
        // Mirror x for a left-hand grip so it follows the gauge to either side.
        let anchorX = UnitPoint(x: leftHanded ? 0.06 : 0.94, y: 0.5)

        // Restrained aura strength: scales with mode energy and warms gently with
        // speed. Brightness only — the radius below is fixed.
        let auraPeak = (0.045 + warmth * 0.05) * intensity

        // Vignette ink — cool near-black in dark; a faint, low-alpha cool gray in
        // light so the frame stays a whisper against paper, never a smudge.
        let shade = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.008, green: 0.010, blue: 0.016, alpha: 1.0)
                : UIColor(red: 0.30, green: 0.30, blue: 0.34, alpha: 0.12)
        })

        return ZStack {
            // 1 · Vignette, beneath the aura so the vermillion still reads at the
            //     lower edge instead of being muted by the frame. Clear through the
            //     center (the word's pocket), falling to ink at the edges.
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.5),
                    .init(color: shade.opacity(0.45), location: 0.82),
                    .init(color: shade.opacity(0.85), location: 1.0),
                ]),
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 120,
                endRadius: 560
            )

            // 2 · A tight, localized instrument glow centered on the gauge. The
            //     radius is small and the opacity collapses fast — effectively gone
            //     by ~80pt — so the gauge reads as alive while the rest of the right
            //     side, and the focal word off to the left, stay dark. A bounded
            //     `frame` keeps the gradient's coordinate box small so it can't wash
            //     the whole edge; it's a halo on the instrument, not a side panel.
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: hue.opacity(auraPeak), location: 0.0),
                    .init(color: hue.opacity(auraPeak * 0.42), location: 0.34),
                    .init(color: hue.opacity(auraPeak * 0.12), location: 0.62),
                    .init(color: .clear, location: 0.82),
                    .init(color: .clear, location: 1.0),
                ]),
                center: anchorX,
                startRadius: 4,
                endRadius: 110
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Full-bleed background: a faint cool lift at the top settling into the deep
/// base. Sits behind every screen for a sense of depth.
struct ReadingCanvas: View {
    var body: some View {
        LinearGradient(
            colors: [.readingCanvasTop, .readingBackground, .readingBackground],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Button styles

/// Filled ink pill — high-contrast editorial primary. The accent is reserved for
/// the thread (your place in the text), so primary actions wear ink instead:
/// black pill/white text on paper, white pill/ink text at night. Flat — no glow.
struct PrimaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.readingBackground)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.readingForeground, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

/// Optional-action pill for the post-read comprehension check. Secondary weight —
/// the same quiet surface + hairline as `SecondaryPillStyle`. The accent no longer
/// marks chrome; the row's small checkmark icon carries the only color. An optional
/// check must never compete with "You finished."
struct ComprehensionPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 13)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(Color.readingSurface, in: Capsule())
            .overlay(Capsule().stroke(Color.readingBorder, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

/// Quiet outlined pill for secondary actions.
struct SecondaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.readingForeground)
            .padding(.vertical, 15)
            // Breathing room on the ends so the label never hugs the capsule's
            // rounded edges — needed when the pill sizes to content (e.g. the
            // completion screen's `.fixedSize`) rather than stretching full width.
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
            .background(Color.readingSurface, in: Capsule())
            .overlay(Capsule().stroke(Color.readingBorder, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}
