# Pleasure Pass: Semantic Replay, Resume Glide, Sensory Polish

**Date:** 2026-07-02
**Status:** Historical — semantic replay, resume glide, paragraph breath, and
sensory polish are implemented.

Three improvements that close the gap between the app as built and the product
spec's "hand-in-glove" feel (`rsvp_casual_reader_spec.md`). No new screens, no
new chrome — every change lives inside the existing reading surface, its
gestures, and its rhythm.

Explicitly out of scope (considered, deferred): phrase-chunk reading mode.

---

## 1. Semantic sentence replay

Replaces the ±12-word rail flicks. The spec names *flick left → replay current
sentence* as the primary recovery action and calls arbitrary-distance jumps a
bad fit; the tokenizer has emitted `sentenceIndex` for this since v1, unused.

### Core (`Sources/SkimCore`)

New pure enum `SentenceNavigation` (sibling of `ReadingNavigation`, which
remains for the scrubber/any other word-math callers):

- `replayTarget(tokens: [ReadingToken], from index: Int) -> Int`
  Index of the first token of the sentence containing `index`.
  **Grace window:** if `index` is within the first 2 tokens of its sentence,
  return the start of the *previous* sentence instead — a flick right after a
  replay (or right as a sentence opens) means "the one before that."
  Clamped: in the first sentence (inside the grace window) returns 0.
  Empty tokens → 0.
- `skipTarget(tokens: [ReadingToken], from index: Int) -> Int`
  Index of the first token of the next sentence. In the last sentence,
  returns `tokens.count - 1` so playback runs out and completes naturally.
  Empty tokens → 0.

Both derive boundaries from `ReadingToken.sentenceIndex` by local scan from
`index` (O(sentence length); no precomputed tables).

### App

- `ReaderIntent.rewind` / `.forward` rename to `.replaySentence` /
  `.skipSentence`; `ReaderGestures` doc comments updated. Zones, flick
  detection, and rail scoping are untouched — only the flick's *meaning*
  changes.
- `ReaderViewModel.rewind12Words()` / `forward12Words()` become
  `replaySentence()` / `skipSentence()`, using the new targets. Same state
  gating as today (live sessions only); replay while playing continues
  playing from the target, replay while paused moves the position and the
  context strip.
- Whatever transient overlay the flicks show today shows the new semantics
  ("Replay sentence" / "Skip sentence" per the spec's overlay examples).

### CoreChecks

- Mid-sentence replay → that sentence's first token.
- Replay within the 2-token grace window → previous sentence's first token.
- Grace window in the first sentence → 0.
- Skip mid-sentence → next sentence's first token.
- Skip in the last sentence → last index.
- Empty tokens → 0 for both.

---

## 2. Resume glide

Re-engaging after a real pause should never feel like being dropped into
moving traffic. The glide is **felt, not shown**: the speed gauge and band
never move (the existing `SpeedRamp` band-ramp stays reserved for explicit
auto-start paths).

### Core

New pure struct `ResumeGlide` (in the `SpeedRamp` style):

- `plan(pauseDuration: Double) -> ResumeGlide?`
  Pause **< 2 s** (a quick brake): `nil` — resume is instant, no back-step,
  so tap-pause-tap never fights the user. Pause **≥ 2 s**: a glide with a
  **3-word back-step** and an ease over the first **8 tokens**.
- `multiplier(atToken k: Int) -> Double`
  `k = 0` → **1.6×**, smoothly (smoothstep) decaying to exactly **1.0×** at
  `k ≥ 8`. Monotonically non-increasing.

Back-step position math reuses `ReadingNavigation.jumpTarget` (already
clamped, already checked).

### App

- `ReaderViewModel` records `pausedAt` when entering `.paused`.
- On resume from `.paused` — via hold (`startHolding`) *or* cruise
  (`enterCruise`) — compute the plan; apply the back-step to `currentIndex`,
  then run the playback loop with the glide multiplier folded into
  `Pacing.secondsPerToken` for the first 8 tokens.
- A backward **replay flick while playing** also applies the ease at its
  landing point (no back-step — the flick chose the position). Forward skips
  do not ease.
- Repositioning **while paused** (replay/skip flick or scrub) clears the
  pending back-step — the user chose that exact spot, so the next resume
  starts there — but the pacing ease still applies if the pause was ≥ 2 s.
- Fresh starts from `.ready` are unchanged (auto-start paths keep their
  existing `SpeedRamp` behavior).

### CoreChecks

- `plan(pauseDuration:)` below threshold → nil; at/above → back-step 3,
  span 8.
- Multiplier: peak at token 0, monotonic, exactly 1.0 from token 8 on.

---

## 3. Sensory polish pass

Targeted refinements to rhythm and haptics — not a rebuild. The haptic map in
`Haptics.swift` is already rich; only the pieces touched by the new semantics
change.

- **Paragraph breath (visual only).** The 2.8× paragraph hold already exists
  in pacing. Add the felt breath: when the *next* token opens a new paragraph
  (`paragraphIndex` advances), insert a **~200 ms empty beat** between words —
  the word canvas clears, the progress thread stays. No haptic: one tick per
  paragraph is noise over a long article.
- **Haptic texture for the new flick semantics.** `Haptics.Event.rewind` /
  `.forward` are replaced:
  - `replaySentence` — medium bump (as today's rewind).
  - `replayPreviousSentence` — double medium bump (the grace-window case;
    same two-pulse pattern as `cruiseOn` but medium), so reaching further
    back *feels* further back.
  - `skipSentence` — lighter than replay (as today's forward).
- **Completion moment.** Sync the finish haptic to the existing thread-draw
  animation: heavy tick as the draw begins, soft echo as it lands — replacing
  the single flat thump.

---

## Testing & verification

1. All pure logic (sentence targets, glide plan/curve) asserted in
   `CoreChecks` in the same change that adds it (`swift run CoreChecks`).
2. `xcodegen generate` + clean `xcodebuild` for the app layer.
3. Device feel-pass via `scripts/deploy-device.sh` (green build only), per
   the spec's "the simulator lies": couch, one-handed, dense text and casual
   article; verify the grace window, the quick-brake exemption, and the
   paragraph breath at real reading speeds.

## Build order

1. **Semantic replay** — core `SentenceNavigation` + checks, then app wiring
   and haptic events.
2. **Resume glide** — core `ResumeGlide` + checks, then view-model wiring
   (reuses replay's landing hook for the flick ease).
3. **Sensory pass** — paragraph breath beat, completion haptic sync.
