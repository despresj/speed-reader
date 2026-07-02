import SwiftUI
import UIKit

/// Crisp, system-aware palette. Cool paper and true ink in light mode; ink-at-night
/// blue-charcoal in dark — with one vivid vermillion "thread" reserved for your
/// place in the text (pivot letter, progress thread, active-word highlight). The
/// light-mode vermillion is deepened so white text on the accent fill meets AA.
extension Color {
    /// Base canvas. A `readingCanvas` gradient is layered on top for depth.
    /// Dark is a *cool* blue-charcoal near-black (#0D0E11); light is crisp cool
    /// paper (#FAFAF8). No warm cast anywhere.
    static let readingBackground = dynamic(
        dark:  UIColor(red: 0.051, green: 0.055, blue: 0.067, alpha: 1),
        light: UIColor(red: 0.980, green: 0.980, blue: 0.973, alpha: 1)
    )

    /// Slightly lifted surface for cards and inputs.
    static let readingSurface = dynamic(
        dark:  UIColor(red: 0.090, green: 0.094, blue: 0.114, alpha: 1),
        light: UIColor(white: 1.0, alpha: 1)
    )

    /// Hairline separators / borders.
    static let readingBorder = dynamic(
        dark:  UIColor(white: 1.0, alpha: 0.10),
        light: UIColor(white: 0.0, alpha: 0.08)
    )

    /// Primary text. Cool off-white (#F2F2F4) in dark to cut glare; true ink
    /// (#16161A), not pure black, in light.
    static let readingForeground = dynamic(
        dark:  UIColor(red: 0.949, green: 0.949, blue: 0.957, alpha: 1),
        light: UIColor(red: 0.086, green: 0.086, blue: 0.102, alpha: 1)
    )

    /// De-emphasized text — hints, placeholders, secondary labels. Cool gray.
    static let readingMuted = dynamic(
        dark:  UIColor(red: 0.557, green: 0.561, blue: 0.596, alpha: 1),
        light: UIColor(red: 0.431, green: 0.431, blue: 0.463, alpha: 1)
    )

    /// The thread: vermillion. Glowing coral-vermillion (#FF6B4A) in dark; deep
    /// vermillion (#C43C24) in light so white-on-accent meets AA.
    static let readingAccent = dynamic(
        dark:  UIColor(red: 1.000, green: 0.420, blue: 0.290, alpha: 1),
        light: UIColor(red: 0.769, green: 0.235, blue: 0.141, alpha: 1)
    )

    /// Color for text/icons sitting on top of the accent fill.
    static let readingOnAccent = dynamic(
        dark:  UIColor(red: 0.051, green: 0.055, blue: 0.067, alpha: 1),
        light: UIColor(white: 1.0, alpha: 1)
    )

    /// The pivot ("optimal recognition point") letter that holds your eye on a
    /// fixed spot as words flash past — the thread stitched through the word.
    /// Same vermillion as `readingAccent` so the reading surface speaks one
    /// color language.
    static let readingPivot = dynamic(
        dark:  UIColor(red: 1.000, green: 0.420, blue: 0.290, alpha: 1),
        light: UIColor(red: 0.769, green: 0.235, blue: 0.141, alpha: 1)
    )

    /// The hot end of the speed ramp: the thread heats from vermillion toward
    /// orange at full speed. Stays in the same family as `readingAccent` so the
    /// surface keeps one color language — just more energized. Energy, not alarm.
    static let readingAccentHot = dynamic(
        dark:  UIColor(red: 1.000, green: 0.541, blue: 0.239, alpha: 1),
        light: UIColor(red: 0.820, green: 0.290, blue: 0.070, alpha: 1)
    )

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
        let top = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.078, green: 0.084, blue: 0.104, alpha: 1)
                : UIColor(red: 1.0, green: 1.0, blue: 0.996, alpha: 1)
        })
        LinearGradient(
            colors: [top, .readingBackground, .readingBackground],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Button styles

/// Filled accent pill with a soft glow and a gentle press-in.
struct PrimaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.readingOnAccent)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.readingAccent, in: Capsule())
            .shadow(color: .readingAccent.opacity(0.35), radius: 18, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

/// Optional-action pill for the post-read comprehension check. Secondary weight —
/// the same dark surface as `SecondaryPillStyle` — but carries a subtle amber
/// accent via its border so it reads as offered, not pushed. The filled amber
/// `PrimaryPillStyle` is reserved for primary reading actions; an optional check
/// must never compete with "You finished."
struct ComprehensionPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 13)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(Color.readingSurface, in: Capsule())
            .overlay(Capsule().stroke(Color.readingAccent.opacity(0.45), lineWidth: 1))
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
