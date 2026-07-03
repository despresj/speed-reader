# Full-surface controls, instant pause context, and color themes

Three changes to the reading surface, in the spirit of the product philosophy:
the surface stays sacred, controls stay physical, and everything the eye meets
stays calm.

## 1 · The paused context appears in place — never scroll-rushes

**Problem.** Pausing mounts the Threadline fresh with its scroll offset at the
top of the prose, then animates to the active word. On any read past the first
screenful that's a fast-scroll blur — motion the reader never asked for.

**Behavior.**
- The **first** centering after the band (re)mounts positions the viewport
  **instantly** (no animated scroll). The band's existing opacity transition is
  the only motion: it *fades in already in place*.
- While the band is up, a recenter whose target is **near** (≤ 1.5 viewport
  heights away — locator tap after a small drift, a sentence flick) keeps the
  smooth animated glide; a **far** target (deep scrub, locator tap after a long
  browse) jumps instantly under a ~0.18s cross-dissolve instead of racing
  through the prose.

**Where.** `Threadline.updateUIView` / `center(_:on:bias:)` only. The recenter
signal (`contextRecenterTick`) is unchanged.

## 2 · The whole screen is the instrument

**Problem.** Hold, tap, and double-tap already work anywhere, but steering — the
vertical speed slide and the horizontal sentence flick — only fires when the
press *began* in the invisible 118pt edge rail. A thumb resting mid-screen that
slides up and gets nothing is the touch-target jank.

**Behavior.** Steering goes global. From any press in a live session:
- slide ↑/↓ → speed band (same deadzone 18pt, same axis-dominance rules)
- flick ←/→ → replay / skip sentence (same 44pt threshold)
- single tap → brake (cruise only); double tap → Cruise toggle — now truly
  anywhere, including over the gauge (the old "swallow rail taps" carve-out is
  gone; a fumbled slide never resolves as a tap anyway).

Unchanged: the paused Threadline band still owns its own touches (native
scroll, hold, double-tap); explicit controls (top bar, scrubber, pills) still
consume their own taps; the gauge is now purely a display.

**Where.** `ReaderGestures.steerIntent` drops its `startZone` gate (core +
CoreChecks assertions updated); `ReadingView` drops the rail guard and the
rail-tap swallow; gesture hints re-worded ("Slide up or down for speed",
"Flick sideways to jump").

## 3 · Five color themes

One palette abstraction, five hand-tuned themes, each with a light and dark
variant (system appearance still decides which). The accent is always "the
thread" — pivot letter, progress, active word — and light-mode accents keep
white-on-accent at AA.

| Theme | Feel | Dark accent | Light accent |
|---|---|---|---|
| **Vermillion** (default) | today's ink + vermillion thread | `#FF6B4A` | `#C43C24` |
| **Tide** | deep ocean blue-black, cyan thread | `#4CC9F0` | `#0369A1` |
| **Moss** | forest charcoal-green, sage thread | `#6FCF97` | `#1B7A46` |
| **Iris** | violet dusk ink, lavender thread | `#A78BFA` | `#6D28D9` |
| **Amber** | warm parchment ember, amber thread | `#F5A524` | `#B45309` |

Each theme defines: background, canvas-top lift, surface, foreground, muted,
accent, accent-hot (the speed-warmth endpoint), on-accent. Hairline borders
stay neutral.

**Mechanics.**
- `App/ThemePalette.swift`: `SkimTheme` enum + per-theme `Palette` of dynamic
  (dark/light) `UIColor`s; `SkimTheme.current` backs the existing
  `Color.reading*` accessors, which become computed. Every existing call site
  keeps compiling untouched; Threadline reads the palette's UIColors directly.
- Selection lives on `ReaderViewModel.theme`, persisted (`skim.theme`),
  matching the other set-once preferences.
- Re-render on change: `ContentView` keys its routing ZStack on the theme
  (`.id`) — an instant, whole-surface swap. The Settings sheet is hoisted to
  a single app-level presentation *outside* that boundary (the three
  per-screen sheets collapse into one), so it survives the swap and you can
  flip through themes live.
- **Settings UI**: a "Theme" row of five tappable swatches (theme background
  disc + accent dot), selected one ringed in its own accent, name shown.
  Selection ticks the selection haptic.

**Out of scope (deliberate).** Video/GIF export keeps its own fixed export
palette; themed export can follow later.
