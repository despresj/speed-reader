# Red Thread Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin Skim from the warm "lamplight" identity to the "Red Thread" identity — cool paper/ink neutrals, a reserved vermillion accent, serif display type, flat ink buttons, and a light motion pass — per `docs/superpowers/specs/2026-07-01-red-thread-redesign-design.md`.

**Architecture:** All color flows through the semantic tokens in `App/Theme.swift` (verified: zero hardcoded colors in views outside `Theme.swift` and `App/FrameRenderer.swift`), so the palette lands in one file and the rest of the work is a font sweep, button-style rewrite, the FrameRenderer export palette, and three small motion changes. `Sources/SkimCore` is untouched.

**Tech Stack:** SwiftUI, UIKit (Threadline bridge + FrameRenderer), xcodegen, xcodebuild (Xcode 26.1.1 confirmed installed).

## Global Constraints

- No changes under `Sources/SkimCore/` — `swift build && swift run CoreChecks` must stay green.
- No UX/structure changes: gestures, layouts, state machine, screen flow, "sacred surface" rule all untouched.
- The streaming reading word stays **sans-serif** (legibility at 650 WPM).
- Vermillion accent values (from spec): light `#C43C24` → RGB(0.769, 0.235, 0.141); dark `#FF6B4A` → RGB(1.0, 0.42, 0.29). Hot ramp: light `#D14A12` → RGB(0.82, 0.29, 0.07); dark `#FF8A3D` → RGB(1.0, 0.541, 0.239). Hue nudges ±5% allowed for contrast; never warm-gold.
- Depth shadows on black (`.shadow(color: .black...)`) stay; **accent glow shadows** on buttons are removed. The speed-gauge accent glows in `ReadingView.swift:1440,1478` stay (they ride the new accent automatically — they're the instrument's warmth, not button chrome).
- Build check used by every task: `cd /Users/joe/skim && xcodebuild -project Skim.xcodeproj -scheme Skim -destination 'generic/platform=iOS Simulator' -quiet build` → expect `** BUILD SUCCEEDED **` (regenerate project first if needed: `xcodegen generate`).
- Commit after every task. Do not run `scripts/deploy-device.sh` until the final task.

---

### Task 1: Theme palette — tokens, canvas, warmth

**Files:**
- Modify: `App/Theme.swift:8-215` (Color extension, `ReadingWarmth`, `ReadingCanvas`)

**Interfaces:**
- Produces: same public token names as today (`readingBackground`, `readingSurface`, `readingBorder`, `readingForeground`, `readingMuted`, `readingAccent`, `readingOnAccent`, `readingPivot`, `readingAccentHot`, `readingAccent(warmth:)`, `readingPivot(warmth:)`), so no caller changes. Threadline, gauges, ProgressLine all inherit.

- [ ] **Step 1: Replace the token values in the `Color` extension**

Replace the doc comment (lines 4–7) and each token's values. New header comment:

```swift
/// Crisp, system-aware palette. Cool paper and true ink in light mode; ink-at-night
/// blue-charcoal in dark — with one vivid vermillion "thread" reserved for your
/// place in the text (pivot letter, progress thread, active-word highlight). The
/// light-mode vermillion is deepened so white text on the accent fill meets AA.
```

New values (each replaces the existing `dynamic(dark:light:)` pair; keep every existing doc comment structure but reword warm→cool as shown):

```swift
    /// Base canvas. Dark is a *cool* blue-charcoal near-black (#0D0E11); light is
    /// crisp cool paper (#FAFAF8). No warm cast anywhere.
    static let readingBackground = dynamic(
        dark:  UIColor(red: 0.051, green: 0.055, blue: 0.067, alpha: 1),
        light: UIColor(red: 0.980, green: 0.980, blue: 0.973, alpha: 1)
    )

    /// Slightly lifted surface for cards and inputs.
    static let readingSurface = dynamic(
        dark:  UIColor(red: 0.090, green: 0.094, blue: 0.114, alpha: 1),
        light: UIColor(white: 1.0, alpha: 1)
    )

    /// Hairline separators / borders. (unchanged values)
    static let readingBorder = dynamic(
        dark:  UIColor(white: 1.0, alpha: 0.10),
        light: UIColor(white: 0.0, alpha: 0.08)
    )

    /// Primary text. Cool off-white (#F2F2F4) in dark; true ink (#16161A) in light.
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

    /// The pivot ("optimal recognition point") letter — the thread stitched through
    /// the word. Same vermillion as `readingAccent`.
    static let readingPivot = dynamic(
        dark:  UIColor(red: 1.000, green: 0.420, blue: 0.290, alpha: 1),
        light: UIColor(red: 0.769, green: 0.235, blue: 0.141, alpha: 1)
    )

    /// The hot end of the speed ramp: the thread heats from vermillion toward
    /// orange at a blast. Energy, not alarm.
    static let readingAccentHot = dynamic(
        dark:  UIColor(red: 1.000, green: 0.541, blue: 0.239, alpha: 1),
        light: UIColor(red: 0.820, green: 0.290, blue: 0.070, alpha: 1)
    )
```

`readingAccent(warmth:)`, `readingPivot(warmth:)`, `lerp`, `dynamic` are unchanged.

- [ ] **Step 2: Cool the `ReadingWarmth` vignette shade and reword its comments**

In `ReadingWarmth` (currently ~line 111–197): the structure, geometry, and opacities all stay. Replace the `shade` definition's warm values with neutral ink:

```swift
        let shade = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.008, green: 0.010, blue: 0.016, alpha: 1.0)
                : UIColor(red: 0.30, green: 0.30, blue: 0.34, alpha: 0.12)
        })
```

Sweep the comments in this struct: replace "amber"/"gold"/"orange-gold"/"warm black" wording with the thread language (e.g. "muted vermillion cruising → hotter orange at a blast", "edges settle into ink"). `hue = Color.readingAccent(warmth:)` is unchanged and picks up the new ramp automatically.

- [ ] **Step 3: Cool the `ReadingCanvas` top glow**

Replace the `top` color in `ReadingCanvas` (~line 201):

```swift
        let top = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.078, green: 0.084, blue: 0.104, alpha: 1)
                : UIColor(red: 1.0, green: 1.0, blue: 0.996, alpha: 1)
        })
```

Reword its doc comment: "a faint cool lift at the top settling into the deep base."

- [ ] **Step 4: Build check**

Run: `swift build && swift run CoreChecks` → exit 0. Then the xcodebuild check from Global Constraints → `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add App/Theme.swift && git commit -m "feat(app): Red Thread palette — cool paper/ink neutrals, vermillion thread accent"
```

---

### Task 2: Button styles — flat ink primary, quiet accents

**Files:**
- Modify: `App/Theme.swift:217-275` (the three ButtonStyles)

**Interfaces:**
- Produces: same style names (`PrimaryPillStyle`, `SecondaryPillStyle`, `ComprehensionPillStyle`); all call sites unchanged.

- [ ] **Step 1: Rewrite `PrimaryPillStyle` as the ink pill**

Replace its `makeBody` contents (accent fill + glow → ink fill, no shadow):

```swift
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
```

- [ ] **Step 2: Drop the amber border from `ComprehensionPillStyle`**

Change its overlay stroke from `Color.readingAccent.opacity(0.45)` to `Color.readingBorder`, and update the doc comment (the accent no longer marks optional actions; the row's checkmark icon still carries a small accent tint from ReviewView, which is fine — it's an icon, not chrome):

```swift
            .overlay(Capsule().stroke(Color.readingBorder, lineWidth: 1))
```

`SecondaryPillStyle` is untouched (already surface + hairline).

- [ ] **Step 3: Build check** — xcodebuild check from Global Constraints → `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add App/Theme.swift && git commit -m "feat(app): flat ink primary pill; accent chrome off buttons"
```

---

### Task 3: App-wide font sweep — kill `.rounded`

**Files:**
- Modify (mechanical, 81 occurrences): `App/PasteView.swift`, `App/ReadingView.swift`, `App/ReviewView.swift`, `App/ResumeView.swift`, `App/IdeasView.swift`, `App/SettingsView.swift`, `App/ExportView.swift`, `App/LinkFallbackView.swift`, `App/Comprehension/AIFeaturesView.swift`, `App/Comprehension/ComprehensionCheckView.swift`, `App/Comprehension/ComprehensionConsentView.swift`

**Interfaces:**
- Produces: all UI text in plain SF Pro (`design:` argument removed). Task 4 then promotes specific display lines to `.serif`.

- [ ] **Step 1: Mechanical removal**

Every occurrence is single-line and comma-preceded (verified by grep). Run:

```bash
cd /Users/joe/skim
sed -i '' 's/, design: \.rounded//g' App/*.swift App/Comprehension/*.swift
grep -rn 'design: \.rounded' App --include='*.swift'   # expect: no output
```

- [ ] **Step 2: Build check** — xcodebuild check from Global Constraints → `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add App App/Comprehension && git commit -m "feat(app): drop rounded type app-wide — plain SF Pro for UI text"
```

---

### Task 4: Serif display type on headings

**Files:**
- Modify: `App/PasteView.swift:153,158` · `App/ReviewView.swift:37` · `App/ResumeView.swift:106` · `App/LinkFallbackView.swift:20` · `App/IdeasView.swift:58` · `App/SettingsView.swift:69` · `App/Comprehension/AIFeaturesView.swift:21` · `App/Comprehension/ComprehensionCheckView.swift:52,112` · `App/Comprehension/ComprehensionConsentView.swift:14`
  (line numbers are pre-Task-3; after the sed they're unchanged — sed edits in place, same line count. Match on the font size/weight shown below.)

**Interfaces:**
- Consumes: Task 3's swept files (these lines now read `.font(.system(size: N, weight: .w))`).

- [ ] **Step 1: Add `design: .serif` to each display line**

Exact transformations (find the line by its size/weight in the named file):

| File | Current (post-Task-3) | New |
|---|---|---|
| PasteView.swift:153 ("Skim" wordmark) | `.font(.system(size: 13, weight: .semibold))` | `.font(.system(size: 13, weight: .semibold, design: .serif))` |
| PasteView.swift:158 (headline) | `.font(.system(size: 30, weight: .bold))` | `.font(.system(size: 30, weight: .bold, design: .serif))` |
| ReviewView.swift:37 ("Done") | `.font(.system(size: 30, weight: .semibold))` | `.font(.system(size: 30, weight: .semibold, design: .serif))` |
| ResumeView.swift:106 (title) | `.font(.system(size: 24, weight: .bold))` | `.font(.system(size: 24, weight: .bold, design: .serif))` |
| LinkFallbackView.swift:20 | `.font(.system(size: 28, weight: .bold))` | `.font(.system(size: 28, weight: .bold, design: .serif))` |
| IdeasView.swift:58 | `.font(.system(size: 22, weight: .semibold))` | `.font(.system(size: 22, weight: .semibold, design: .serif))` |
| SettingsView.swift:69 | `.font(.system(size: 22, weight: .semibold))` | `.font(.system(size: 22, weight: .semibold, design: .serif))` |
| AIFeaturesView.swift:21 | `.font(.system(size: 22, weight: .semibold))` | `.font(.system(size: 22, weight: .semibold, design: .serif))` |
| ComprehensionCheckView.swift:52 | `.font(.system(size: 20, weight: .semibold))` | `.font(.system(size: 20, weight: .semibold, design: .serif))` |
| ComprehensionCheckView.swift:112 | `.font(.system(size: 34, weight: .bold))` | `.font(.system(size: 34, weight: .bold, design: .serif))` |
| ComprehensionConsentView.swift:14 | `.font(.system(size: 22, weight: .semibold))` | `.font(.system(size: 22, weight: .semibold, design: .serif))` |

Do **not** serif anything in `ReadingView.swift` — the streaming word and all reading-surface chrome stay sans.

- [ ] **Step 2: Build check** — xcodebuild check from Global Constraints → `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add App App/Comprehension && git commit -m "feat(app): New York serif display headings"
```

---

### Task 5: FrameRenderer export palette + type

**Files:**
- Modify: `App/FrameRenderer.swift:46-50` (palette), `:219-223` (font), comments at `:5-7,84,178`

**Interfaces:**
- Produces: exports match the app's new dark scheme. No signature changes.

- [ ] **Step 1: Replace the fixed export palette**

The export is always dark-scheme; use the new dark values from Task 1:

```swift
    // The reader's dark palette, fixed for the export (the video isn't system-aware).
    private let bg = UIColor(red: 0.051, green: 0.055, blue: 0.067, alpha: 1)
    private let bgGlow = UIColor(red: 0.078, green: 0.084, blue: 0.104, alpha: 1)
    private let fg = UIColor(red: 0.949, green: 0.949, blue: 0.957, alpha: 1)
    private let muted = UIColor(red: 0.557, green: 0.561, blue: 0.596, alpha: 1)
    private let accent = UIColor(red: 1.000, green: 0.420, blue: 0.290, alpha: 1)
```

- [ ] **Step 2: Drop the rounded design from the export font**

Replace `roundedFont` with a plain system font (keep the name-agnostic call sites simple by renaming to `wordFont` and updating the 7 call sites — `drawWord`, `measure`, `drawTitleCard` ×2, `drawEndCard`, `drawWatermark`):

```swift
    /// Plain SF Pro matching the app's UI type. The streaming word stays sans.
    private func wordFont(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }
```

Update the header comment ("warm-dark palette, the gold ORP pivot" → "ink-dark palette, the vermillion ORP pivot") and the `drawBackground`/watermark comments ("warm glow" → "cool lift"; "warm accent" → "vermillion").

- [ ] **Step 3: Build check** — xcodebuild check from Global Constraints → `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add App/FrameRenderer.swift && git commit -m "feat(app): exports render in the Red Thread palette"
```

---

### Task 6: Screen transitions in ContentView

**Files:**
- Modify: `App/ContentView.swift` (whole file — it's 26 lines)

**Interfaces:**
- Consumes: `viewModel.pendingLink`, `viewModel.pendingResume`, `viewModel.state` (all existing).

- [ ] **Step 1: Route through an enum and animate the swap**

Replace the body with a ZStack + switch so SwiftUI treats each screen as a distinct identity and animates insertion/removal:

```swift
import SwiftUI

/// Routes between the paste screen (no text) and the reading surface, with a soft
/// crossfade + settle between screens instead of a hard swap.
struct ContentView: View {
    let viewModel: ReaderViewModel
    let ideas: IdeasViewModel

    private enum Route: Equatable { case link, resume, paste, review, reading }

    private var route: Route {
        if viewModel.pendingLink != nil { return .link }
        if viewModel.pendingResume != nil && viewModel.state == .idle { return .resume }
        if viewModel.state == .idle { return .paste }
        if viewModel.state == .completed { return .review }
        return .reading
    }

    var body: some View {
        ZStack {
            switch route {
            case .link:
                LinkFallbackView(viewModel: viewModel).transition(screenTransition)
            case .resume:
                if let resume = viewModel.pendingResume {
                    ResumeView(viewModel: viewModel, candidate: resume).transition(screenTransition)
                }
            case .paste:
                PasteView(viewModel: viewModel).transition(screenTransition)
            case .review:
                ReviewView(viewModel: viewModel).transition(screenTransition)
            case .reading:
                ReadingView(viewModel: viewModel, ideas: ideas).transition(screenTransition)
            }
        }
        .animation(.easeOut(duration: 0.25), value: route)
        // Keep the reading screen lit while engaged with the thumb.
        .persistentSystemOverlays(.hidden)
    }

    private var screenTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }
}
```

Note the `.resume` case guards `pendingResume` again inside the switch (it can go nil between route computation and render); behavior matches today's `if let`.

- [ ] **Step 2: Build check** — xcodebuild check from Global Constraints → `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add App/ContentView.swift && git commit -m "feat(app): soft crossfade between screens"
```

---

### Task 7: Motion moments — springy estimate pill, completion thread-draw

**Files:**
- Modify: `App/PasteView.swift` (estimate pill, ~lines 228-248)
- Modify: `App/ReviewView.swift` (header, ~lines 34-45)

**Interfaces:**
- Consumes: `Color.readingAccent` (Task 1). The finish haptic already fires in `ReaderViewModel.finish()` (`App/ReaderViewModel.swift:1062`) — do NOT add another.

- [ ] **Step 1: Estimate pill springs in**

In `PasteView.estimatePill`, replace the transition/animation lines:

```swift
            .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
```

and remove the `.animation(.easeOut(duration: 0.2), value: estimate)` line from the pill. Then attach the animation where the insertion is visible — on the outer `VStack(spacing: 0)` in `body` (after its `.padding` modifiers):

```swift
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: estimate)
```

- [ ] **Step 2: Completion thread-draw in ReviewView**

Add state to `ReviewView`:

```swift
    @State private var threadDrawn = false
```

In `header`, insert a thread line between "Done" and the meta line (inside the `VStack(spacing: 8)`), and trigger it on appear:

```swift
            Capsule()
                .fill(Color.readingAccent)
                .frame(width: 64, height: 2)
                .scaleEffect(x: threadDrawn ? 1 : 0.02, anchor: .leading)
                .opacity(threadDrawn ? 1 : 0)
```

and on the header's `VStack` (alongside `.frame(maxWidth: .infinity)`):

```swift
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) {
                threadDrawn = true
            }
        }
```

Also update the file-header comment ("the same warm, dim reading-by-lamplight surface" → "the same calm ink-and-paper surface").

- [ ] **Step 3: Build check** — xcodebuild check from Global Constraints → `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add App/PasteView.swift App/ReviewView.swift && git commit -m "feat(app): estimate pill springs in; completion draws the thread"
```

---

### Task 8: Comment sweep, verification, deploy

**Files:**
- Modify: any remaining "amber/gold/lamplight/warm" comment references in `App/*.swift` (comments only — find with the grep below)
- No source-logic changes in this task.

- [ ] **Step 1: Sweep stale warm-palette comments**

```bash
grep -rn -i 'amber\|gold\|lamplight' App --include='*.swift'
```

Rewrite each hit's *comment text* to thread/vermillion language (e.g. ReadingView's "the active word in amber" → "in vermillion", Threadline's doc comment). Do not change any code on these lines.

- [ ] **Step 2: Full build verification**

```bash
swift build && swift run CoreChecks           # core untouched, must exit 0
xcodegen generate
xcodebuild -project Skim.xcodeproj -scheme Skim -destination 'generic/platform=iOS Simulator' -quiet build
```
Expected: CoreChecks exit 0; `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Visual verification in the simulator, both schemes**

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; open -a Simulator
xcodebuild -project Skim.xcodeproj -scheme Skim -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build
APP=$(find ~/Library/Developer/Xcode/DerivedData -path '*Debug-iphonesimulator/Skim.app' | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch --terminate-running-process booted com.despresj.skim SKIM_SAMPLE=1 2>/dev/null \
  || SIMCTL_CHILD_SKIM_SAMPLE=1 xcrun simctl launch --terminate-running-process booted com.despresj.skim
xcrun simctl io booted screenshot /private/tmp/claude-501/-Users-joe-skim/*/scratchpad/skim-light.png 2>/dev/null || xcrun simctl io booted screenshot /tmp/skim-light.png
xcrun simctl ui booted appearance dark && sleep 1 && xcrun simctl io booted screenshot /tmp/skim-dark.png
```

(If the device name differs, list with `xcrun simctl list devices available | grep iPhone` and pick the newest.) Inspect the screenshots (Read tool) against the checklist: Paste screen (serif headline, cool paper/ink, estimate pill vermillion), Reading (vermillion pivot + progress thread, gauge aura vermillion at high band), paused Threadline (active word vermillion), Review (serif "Done", thread-draw, ink pills flat), Settings sheet. Check **both** appearances. Fix anything off (contrast, missed warm color) before proceeding.

- [ ] **Step 4: Export spot-check**

In the simulator app, run a short GIF export from a small read and confirm the frames are ink-dark with a vermillion pivot (or, faster: visually confirm `ExportView`'s live preview, which renders through `FrameRenderer`).

- [ ] **Step 5: Commit**

```bash
git add -A App && git commit -m "chore(app): sweep stale lamplight comments; Red Thread verification pass"
```

- [ ] **Step 6: Deploy to Joe's iPhone (only on the green build above)**

```bash
scripts/deploy-device.sh
```
Expected: script builds clean and installs + launches on device UDID `00008140-001C28661142801C`.
