import UIKit

/// Skim's five hand-tuned color themes. Each is a complete palette with a light
/// and a dark variant — the system appearance still decides which one renders —
/// and each keeps the product's one color rule: the accent is *the thread* (pivot
/// letter, progress, active word, live WPM), never chrome. Light-mode accents are
/// deep enough that white-on-accent meets AA.
///
/// Selection lives on `ReaderViewModel.theme` (persisted); the live value is
/// mirrored into `SkimTheme.current`, which every `Color.reading*` accessor in
/// `Theme.swift` resolves through. Views re-render on a change because
/// `ContentView` keys its routing surface on the theme.
enum SkimTheme: String, CaseIterable, Identifiable {
    /// Cool paper and true ink with the vermillion thread — the original Skim.
    case vermillion
    /// Deep ocean blue-black; the thread is a bright cyan tide-light.
    case tide
    /// Forest charcoal-green; the thread is spring sage.
    case moss
    /// Violet dusk ink; the thread is lavender.
    case iris
    /// Warm parchment ember; the thread is amber.
    case amber

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vermillion: "Vermillion"
        case .tide:       "Tide"
        case .moss:       "Moss"
        case .iris:       "Iris"
        case .amber:      "Amber"
        }
    }

    static let defaultsKey = "skim.theme"

    /// The live theme, read by every color accessor. Written only from the main
    /// thread (the view model's `theme` didSet); `nonisolated(unsafe)` because the
    /// `Color.reading*` accessors are called from non-isolated SwiftUI contexts
    /// (button styles) that are main-thread in practice.
    nonisolated(unsafe) static var current: SkimTheme =
        SkimTheme(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "")
        ?? .vermillion

    /// The complete role → color mapping for this theme.
    var palette: ThemePalette {
        switch self {
        case .vermillion:
            ThemePalette(
                background: (rgb(0.051, 0.055, 0.067), rgb(0.980, 0.980, 0.973)),
                canvasTop:  (rgb(0.078, 0.084, 0.104), rgb(1.000, 1.000, 0.996)),
                surface:    (rgb(0.090, 0.094, 0.114), rgb(1.000, 1.000, 1.000)),
                foreground: (rgb(0.949, 0.949, 0.957), rgb(0.086, 0.086, 0.102)),
                muted:      (rgb(0.557, 0.561, 0.596), rgb(0.431, 0.431, 0.463)),
                accent:     (rgb(1.000, 0.420, 0.290), rgb(0.769, 0.235, 0.141)),
                accentHot:  (rgb(1.000, 0.541, 0.239), rgb(0.820, 0.290, 0.070)),
                onAccent:   (rgb(0.051, 0.055, 0.067), rgb(1.000, 1.000, 1.000)))
        case .tide:
            ThemePalette(
                background: (rgb(0.039, 0.059, 0.086), rgb(0.969, 0.980, 0.988)),
                canvasTop:  (rgb(0.059, 0.086, 0.125), rgb(1.000, 1.000, 1.000)),
                surface:    (rgb(0.067, 0.098, 0.145), rgb(1.000, 1.000, 1.000)),
                foreground: (rgb(0.937, 0.949, 0.965), rgb(0.075, 0.098, 0.129)),
                muted:      (rgb(0.520, 0.570, 0.640), rgb(0.400, 0.450, 0.520)),
                accent:     (rgb(0.298, 0.788, 0.941), rgb(0.012, 0.412, 0.631)),
                accentHot:  (rgb(0.350, 0.870, 1.000), rgb(0.000, 0.455, 0.702)),
                onAccent:   (rgb(0.039, 0.059, 0.086), rgb(1.000, 1.000, 1.000)))
        case .moss:
            ThemePalette(
                background: (rgb(0.047, 0.063, 0.051), rgb(0.969, 0.980, 0.961)),
                canvasTop:  (rgb(0.071, 0.094, 0.078), rgb(1.000, 1.000, 0.996)),
                surface:    (rgb(0.082, 0.110, 0.090), rgb(1.000, 1.000, 1.000)),
                foreground: (rgb(0.941, 0.953, 0.941), rgb(0.078, 0.098, 0.082)),
                muted:      (rgb(0.530, 0.590, 0.540), rgb(0.400, 0.460, 0.410)),
                accent:     (rgb(0.435, 0.812, 0.592), rgb(0.106, 0.478, 0.275)),
                accentHot:  (rgb(0.620, 0.880, 0.420), rgb(0.290, 0.550, 0.100)),
                onAccent:   (rgb(0.047, 0.063, 0.051), rgb(1.000, 1.000, 1.000)))
        case .iris:
            ThemePalette(
                background: (rgb(0.059, 0.051, 0.086), rgb(0.980, 0.976, 0.988)),
                canvasTop:  (rgb(0.086, 0.075, 0.125), rgb(1.000, 0.996, 1.000)),
                surface:    (rgb(0.098, 0.086, 0.145), rgb(1.000, 1.000, 1.000)),
                foreground: (rgb(0.949, 0.945, 0.965), rgb(0.094, 0.082, 0.118)),
                muted:      (rgb(0.570, 0.550, 0.630), rgb(0.440, 0.420, 0.490)),
                accent:     (rgb(0.655, 0.545, 0.980), rgb(0.427, 0.157, 0.851)),
                accentHot:  (rgb(0.831, 0.545, 0.969), rgb(0.580, 0.150, 0.750)),
                onAccent:   (rgb(0.059, 0.051, 0.086), rgb(1.000, 1.000, 1.000)))
        case .amber:
            ThemePalette(
                background: (rgb(0.071, 0.063, 0.043), rgb(0.980, 0.965, 0.925)),
                canvasTop:  (rgb(0.098, 0.088, 0.063), rgb(0.996, 0.988, 0.965)),
                surface:    (rgb(0.110, 0.098, 0.071), rgb(1.000, 0.992, 0.969)),
                foreground: (rgb(0.965, 0.949, 0.925), rgb(0.114, 0.098, 0.071)),
                muted:      (rgb(0.620, 0.580, 0.510), rgb(0.470, 0.430, 0.370)),
                accent:     (rgb(0.961, 0.647, 0.141), rgb(0.706, 0.325, 0.035)),
                accentHot:  (rgb(0.980, 0.520, 0.180), rgb(0.780, 0.250, 0.060)),
                onAccent:   (rgb(0.071, 0.063, 0.043), rgb(1.000, 1.000, 1.000)))
        }
    }
}

/// One theme's role → color mapping. Every role carries its dark and light
/// variant; hairline borders stay theme-neutral (see `Color.readingBorder`).
struct ThemePalette {
    typealias Pair = (dark: UIColor, light: UIColor)

    /// Base canvas. A `readingCanvas` gradient (topped by `canvasTop`) layers on
    /// top for depth.
    let background: Pair
    /// The faint lift at the top of the full-bleed canvas gradient.
    let canvasTop: Pair
    /// Slightly lifted surface for cards, pills, and inputs.
    let surface: Pair
    /// Primary text.
    let foreground: Pair
    /// De-emphasized text — hints, placeholders, secondary labels.
    let muted: Pair
    /// The thread: pivot letter, progress fill, active word, live WPM.
    let accent: Pair
    /// The hot end of the speed ramp — the accent energized, never an alarm.
    let accentHot: Pair
    /// Text/icons sitting on top of an accent fill.
    let onAccent: Pair

    /// A trait-resolving UIColor for a role — the bridge for UIKit consumers
    /// (the Threadline's attributed text) and the SwiftUI accessors alike.
    static func uiColor(_ pair: Pair, alpha: CGFloat = 1) -> UIColor {
        UIColor { trait in
            let base = trait.userInterfaceStyle == .dark ? pair.dark : pair.light
            return alpha < 1 ? base.withAlphaComponent(alpha) : base
        }
    }
}

private func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
    UIColor(red: r, green: g, blue: b, alpha: 1)
}
