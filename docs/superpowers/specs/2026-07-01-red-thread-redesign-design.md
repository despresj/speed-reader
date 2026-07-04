# Red Thread Redesign — Design Spec

**Date:** 2026-07-01
**Status:** Historical — implemented and subsequently generalized into five
selectable light/dark themes.

## Why

The current "reading by lamplight" identity (warm sepia paper, gold accent, `.rounded`
type, soft glows) reads as too warm, too timid, and Joe is tired of it. Skim's own
language already contains a stronger identity: the tagline is *"Read faster without
losing the thread"* and the pause context band is named **Threadline**. This redesign
makes the app wear that identity.

**Concept — "The Red Thread":** a crisp paper-and-ink editorial base with a single
vivid vermillion thread running through everything that means *your place in the
text*. Cool-neutral instead of sepia; high-contrast and confident instead of muted;
a genuinely new direction, not a tweak.

Directions considered and rejected: *phosphor instrument* (cool dark + electric
green — kinetic but cold, fights the spec's "calm casual flow-reading instrument");
*midnight electric indigo* (modern but generic OLED-app look, not ownable).

## Non-goals

- No UX/structure changes: gestures, layouts, state machine, screen flow, and the
  "sacred surface" rule (no buttons/toolbars while reading) are all untouched.
- No `SkimCore` changes. `swift build` / `CoreChecks` remain green by construction.
- App icon is an optional stretch at the end, not part of the core sweep.

## 1 · Palette (Theme.swift color tokens)

All existing token *names* keep their meaning; only values change. Threadline,
buttons, and most views already draw from these tokens, so the palette flows
through automatically.

| Token | Light ("paper") | Dark ("ink at night") |
|---|---|---|
| `readingBackground` | cool off-white paper `#FAFAF8` | blue-charcoal near-black `#0D0E11` |
| `readingSurface` | white | lifted cool charcoal `#17181D` |
| `readingBorder` | black @ 8% | white @ 10% |
| `readingForeground` | true ink `#16161A` | cool off-white `#F2F2F4` |
| `readingMuted` | cool gray `#6E6E76` | cool gray `#8E8F98` |
| `readingAccent` | deep vermillion `#C43C24` (AA with white on fill) | glowing coral-vermillion `#FF6B4A` |
| `readingOnAccent` | white | near-black ink |
| `readingPivot` | = `readingAccent` | = `readingAccent` |
| `readingAccentHot` | burnt hot orange `≈#D14A12` | hot orange `≈#FF8A3D` |

Exact values may be nudged ±5% during implementation for contrast, but hue families
are fixed: neutral-cool grays, vermillion→orange heat ramp. **Nothing warm-gold
survives anywhere.**

- **Speed-warmth ramp** (`readingAccent(warmth:)` / `readingPivot(warmth:)`): same
  mechanism, re-tuned — the thread heats from vermillion toward hot orange as the
  speed band climbs.
- **`ReadingCanvas`**: keep the subtle top-glow gradient, cooled to the new neutrals
  (faint cool lift in dark; near-white in light). No warm cast.
- **`ReadingWarmth`** (vignette + instrument aura): structure unchanged; vignette
  shade becomes neutral ink, aura hue rides the new thread heat.

## 2 · The thread motif — accent discipline

Vermillion is **reserved for "your place in the text"** and nothing else:

- The ORP pivot letter in the streaming word.
- The bottom progress line — restyled as *the thread being drawn across the
  screen* (same geometry, thread color).
- The active-word highlight in the Threadline band (`activeColor` already maps to
  `readingAccent` — flows through).
- The read-time estimate value on PasteView — the one forward-looking use: the
  thread you're about to pick up.

**Buttons stop using the accent.** New button language, flat and editorial:

- `PrimaryPillStyle` → **ink pill**: `readingForeground` fill with
  `readingBackground` text (black pill/white text in light; white pill/dark text in
  dark). Remove the glow `shadow`. Keep the press-in spring.
- `SecondaryPillStyle` → unchanged structure (surface + hairline), new tokens.
- `ComprehensionPillStyle` → surface pill with a hairline `readingBorder` stroke;
  drop the amber-tinted border (accent no longer marks optional actions).

## 3 · Typography

- Drop `design: .rounded` app-wide (~60 uses across 8+ view files) — the main
  source of the "soft" feel.
- **Display/headings** (PasteView header, Review/completion headline, Resume,
  empty states): system **serif (New York)**, e.g.
  `.font(.system(size: 30, weight: .bold, design: .serif))`. Editorial confidence.
- **UI body, labels, buttons, pills**: plain SF Pro (`design: .default`), same
  sizes/weights as today unless a spot clearly needs rebalancing.
- **The streaming reading word: stays sans-serif** — legibility at 650 WPM is
  non-negotiable. Pivot letter in thread vermillion via existing token.
- The wordmark "Skim" on PasteView: serif, keeps its letter-spacing treatment.

## 4 · Motion & feel pass

- **Screen transitions:** ContentView currently hard-swaps Paste ↔ Reading ↔
  Review. Add a soft crossfade + slight scale (`.transition(.opacity
  .combined(with: .scale(0.98)))` with a short ease) on the routed screens.
- **Completion moment:** on reaching `.completed`, the thread/progress line draws
  to full width with a spring before the Review content appears; success haptic
  (via existing `Haptics`) if not already present.
- **Estimate pill:** springs in (scale + fade) instead of plain opacity.
- Nothing else on the reading surface moves differently; pacing/gesture feel is
  untouched.

## 5 · Sweep scope

Files to restyle (tokens mostly flow through; work is fonts, button styles,
removed glows, and any hardcoded warm colors):

- `App/Theme.swift` — token values, canvas/warmth neutrals, button styles (core of
  the change).
- `App/PasteView.swift`, `ReadingView.swift`, `ReviewView.swift`,
  `ResumeView.swift`, `IdeasView.swift`, `SettingsView.swift`, `ExportView.swift`,
  `LinkFallbackView.swift`, `Comprehension/AIFeaturesView.swift`,
  `Comprehension/ComprehensionCheckView.swift`, `ComprehensionConsentView.swift` —
  font sweep + any local color/glow cleanup.
- `App/Threadline.swift` — colors flow from tokens; verify attributed-string
  colors resolve correctly in both schemes.
- `App/FrameRenderer.swift` — **hardcodes the old lamplight palette** (bg, glow,
  fg, muted, accent as literal `UIColor(red:…)`) for GIF/video export frames.
  Update to the new dark-scheme values so exports match the app.
- `App/ContentView.swift` — transition animation.

## 6 · Verification

- `swift build && swift run CoreChecks` (should be trivially green — core
  untouched; run anyway).
- Clean `xcodegen generate` + `xcodebuild` for the app target.
- Visual check in both color schemes (simulator light/dark) on: Paste, Reading
  (incl. paused Threadline + speed gauge at low/high band), Review, Resume,
  Settings, Export preview, Comprehension check.
- Export a short GIF/video and confirm frames use the new palette.
- On a green build: `scripts/deploy-device.sh` to Joe's iPhone.

## 7 · Stretch (separate, optional)

New app icon: ink field with a vermillion thread motif. Only after the sweep
lands and Joe has lived with the new look on device.
