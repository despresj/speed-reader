# Repository guidance

## Product and documentation authority

Skim is a calm, clipboard-first RSVP reading instrument for iPhone. It is not a
speed-reading scoreboard or document-management system.

Read [docs/README.md](docs/README.md) before planning work. It defines the active
documents and their precedence:

- `docs/skim-product-philosophy.md` — product principles;
- `docs/trance-pass-spec.md` — canonical roadmap and delivery order;
- focused specs linked by the roadmap, currently `docs/tokenizer-spec.md`;
- `docs/superpowers/` and `rsvp_casual_reader_spec.md` — historical context only.

Do not infer backlog from a historical implementation plan.

## Build and verification

Pure core verification:

```sh
swift build
swift run CoreChecks
```

`CoreChecks` is the dependency-free test harness. Add assertions in
`Sources/CoreChecks/main.swift` in the same change as any new core behavior.

iOS build:

```sh
xcodegen generate
xcodebuild -project Skim.xcodeproj -scheme Skim \
  -destination 'generic/platform=iOS Simulator' build
```

`Skim.xcodeproj` is generated from `project.yml` and ignored. Edit
`project.yml`, never the generated project.

For a physical-device feel pass, deploy only after core and Xcode builds are
green:

```sh
scripts/deploy-device.sh
```

Set `SKIM_SAMPLE` in the launch environment to preload development text.

## Architecture

### `Sources/SkimCore`

Pure Swift/Foundation logic with no UIKit or SwiftUI imports:

- `Tokenizer` emits word tokens with rhythm and sentence/paragraph metadata.
- `Pacing`, `SpeedBand`, and `SpeedRamp` own timing and the 300–1000 WPM grid.
- `SentenceNavigation`, `ReadingNavigation`, and `ResumeGlide` own movement and
  re-entry behavior.
- `ORP`, `PivotFitSolver`, and `ReadingContext` own display-independent text
  geometry and context reconstruction.
- `SkimStore` owns local SQLite persistence for reads, ideas, and comprehension.
- `Comprehension/` owns provider-independent models, validation, scoring,
  planning, and sampling.

Core logic belongs here when it can be expressed without app frameworks.

### `App`

SwiftUI and platform integration:

- `ReaderViewModel` owns reading state, tokenization, playback, persistence,
  imports, overlay coordination, and haptic events.
- `ContentView` routes link fallback, resume, paste, reading, and review states.
- `ReadingView` owns the reading surface and gesture recognition; hold, tap,
  speed slide, and sentence flick work across the live surface.
- `Threadline` presents native paused prose context.
- `ThemePalette` and `Theme` provide five dynamic palettes.
- export files produce MP4/GIF artifacts from the same pacing primitives.
- `App/Comprehension` contains BYOK OpenAI transport, Keychain storage, and UI.

The app target compiles `App/` and `Sources/SkimCore/` together, so app code uses
core types without `import SkimCore`.

## Behavioral constraints

- Keep the active reading surface visually quiet; controls are gestures and
  temporary feedback, not permanent chrome.
- Preserve word-based semantics for counts, progress, persistence, and exports
  when token representation changes.
- Never infer sentence or clause meaning from a delay multiplier.
- Keep network and Keychain work in the existing comprehension boundaries.
- Do not add developer-owned API keys, accounts, analytics, streaks, or speed
  gamification.
- Treat physical-device reading as required verification for gesture, pacing,
  haptic, and phrase-layout changes.

## Working-tree conventions

- Preserve unrelated user changes.
- `.build/`, generated Xcode projects, and user-specific Xcode state are ignored.
- Use the existing semantic color and haptic abstractions instead of hardcoded
  values in views.
