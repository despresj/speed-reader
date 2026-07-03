# The trance pass — remove trance-breakers before adding surfaces

Four passes, shipped in order. Passes 1–3 are the product finally becoming what
`skim-product-philosophy.md` claims it is; pass 4 teaches it. The governing
principle: **the app wins when it feels inevitable, not configurable.** Every
item below is held to the philosophy's one-line test — does it hand attention
back, or quietly take it away?

Explicitly refused, permanently: stats, streaks, reading goals, font pickers,
AI summaries, more settings knobs, unlimited themes, dashboards.

---

## Pass 1 · Keep the screen awake; answer "can I finish this?"

### 1a. Idle timer (ship blocker)

Cruise mode — the flagship "be carried" mode — has no touches, so iOS dims and
locks the phone mid-paragraph. The core promise breaks silently.

**Design.** The *decision* is pure core; the *side effect* is one line in the
view model.

- `Sources/SkimCore/ScreenWake.swift`:
  `ScreenWake.shouldStayAwake(_ state: ReaderState) -> Bool` — true for
  `.precisionHeld` and `.cruisePlaying`, false for every other state
  (idle, ready, paused, completed).
- `ReaderViewModel` applies it at the single state-transition choke point:
  `UIApplication.shared.isIdleTimerDisabled = ScreenWake.shouldStayAwake(state)`.
  Restore is *aggressive*: every pause path, background transition
  (`pauseForBackground` already forces `.paused`, which restores it), completion,
  and clear/teardown all flow through state changes, so driving it off the state
  didSet covers all of them by construction.
- CoreChecks: assert the mapping for **all six** `ReaderState` cases, so a new
  state can't silently leak a wake lock or a sleep.

### 1b. Time left, not progress math

`412 / 1,920 · 21%` is engineer telemetry wearing a consumer costume. The human
question is *"can I finish this?"*

**Design.**
- Core: `ReadTimeEstimate.remainingSeconds(tokens:from:wpm:)` — sum of the
  *remaining* tokens' paced durations (delay multipliers included), i.e. the
  same honest arithmetic `seconds(tokens:wpm:)` already does, from an index.
  CoreChecks: remaining(0) == total, remaining(count) == 0, monotonically
  non-increasing, multiplier-aware (a paragraph-heavy tail estimates longer).
- UI, calm and muted, never a metric display:
  - **Scrub readout** becomes `~4 min left · 21%` (time first, percent as the
    quiet secondary; token counts gone).
  - **Paused**: a faint `~4 min left` in the muted tier near the progress line,
    pause-chrome-gated like the top bar (present at rest, gone while streaming).
  - **Cruise/hold: nothing.** No live countdown while reading — that would be
    productivity-coded pressure, exactly what the philosophy forbids.
- Label via the existing `ReadTimeEstimate.compact` (`0:42`, `9:59`, `24 min`),
  prefixed `~`. Recomputed on pause/scrub only — never per-token during
  playback (no ticking clock).

---

## Pass 2 · TextCleanup — the read feels clean, never rewritten

A pure, deterministic SkimCore pass: `TextCleanup.clean(_ text: String) -> String`,
run in the load pipeline **after** `Markdown.strip`, **before** `Tokenizer.tokenize`.

**The fence: restraint.** Never rewrite prose, never summarize, never get cute.
When in doubt, KEEP. Only mechanical debris that breaks flow:

| Rule | Action |
|---|---|
| Raw URLs (`https://…`, `www.…`) | collapse to readable domain token (`nytimes.com`) |
| Bracketed citations `[1]`, `[note 3]`, `[citation needed]` | strip inline |
| Newsletter/social boilerplate | remove **whole lines only**, tight patterns (subscribe / sign up / follow us / share this / advertisement / sponsored / read more / related articles) |
| Photo & credit lines (`Photo:`, `Image:`, `Credit:`, Getty, AP) | remove whole line |
| Unicode debris | NBSP→space, zero-width chars & soft hyphens stripped, repeated whitespace collapsed; typographic quotes/dashes **preserved** |

Each rule is its own testable function; `clean` composes them in a fixed order.
Exact rule set, ordering, and false-positive fences per the design-panel
synthesis (appended to this doc when the panel reports).

**Fixture suite** in CoreChecks — the quality bar for this pass: NYT-style,
Substack, Wikipedia, academic, Reddit, RSS-garbage, dialogue fiction,
number-dense finance, code-adjacent, URL-riddled newsletter, abbreviation
stress test, degenerate edges. Every fixture asserts both what is stripped
*and* what is kept verbatim.

---

## Pass 3 · Phrase chunking — the reader becomes humane

Single-word RSVP is a demo; phrase RSVP is the product. 2–4 word chunks are the
**default for fresh reads**; word mode remains as the automatic fallback for
dense/code-ish text. Implemented as a **tokenizer mode, not a UI feature** — no
settings knob in this pass.

**Invariants (non-negotiable):**
- **Honest WPM.** Total read time at N wpm ≈ word count × 60/N, chunked or not.
  A chunk's delay composes from its words' delays with a small density factor
  so multi-word chunks read as one calm fixation — never a slot machine.
- **Boundaries.** A chunk never crosses punctuation, sentence, or paragraph.
- **Cohesion.** Leading function words (articles, prepositions, conjunctions,
  short pronouns) attach to the following content word; a chunk never ends on
  a dangling function word when avoidable; names/initials stay together.
- **Standalone fallbacks.** Long words (≥13 chars), URLs/domains, complex
  numbers, code-ish fragments display alone.
- **Pivot.** The ORP letter anchors on the chunk's first content word; wide
  chunks resolve through the existing `PivotFitSolver` (shrink before shift).
- **Compatibility.** `sentenceIndex`/`paragraphIndex`/`tokenIndex` semantics
  survive; Threadline `proseMap`, sentence replay/skip, paragraph breath, and
  the scrubber keep working with chunk-granularity tokens.
- **Sentence detection hardening** ships inside this pass: initials
  ("J. K. Rowling"), decimals (3.14), ellipsis, closing quotes after
  terminators, expanded abbreviation coverage.

Final algorithm (rule tables, density factors, API shape, migration notes) per
the design-panel synthesis — appended below when the panel reports. Deterministic
rules only; no NaturalLanguage dependency, so CoreChecks stays hermetic.

**Feel-testing is part of the definition of done:** deploy to device and read
three real pastes (news article, dense email, fiction) before calling it shipped.

---

## Pass 4 · The first read teaches itself

Replace explanation with embodied learning. A bundled ~200-word sample read
*about the gestures* — it tells you to hold as you hold, to slide as it streams,
to flick left when it plants a thought worth replaying, to lift your thumb and
see the Threadline catch you.

- Offered on true first launch (no persisted reads, hints unseen) as a quiet
  primary affordance on the paste screen: "Take your first read".
- The gesture-hints overlay is suppressed for the sample (the text *is* the
  lesson); it still exists for text-first arrivals and the menu.
- The sample is a normal read (same pipeline, no special casing in the reader).

---

## Execution order

1. **Idle timer + time left** — smallest fixes, immediate credibility.
2. **Cleanup pipeline** — every existing read gets better; pure core + fixtures.
3. **Phrase chunking** — hardest, most important; dedicated fixtures + on-device feel pass.
4. **First-read demo** — teach it elegantly once the core is worth teaching.

Then (separate passes, explicitly *after* the trance work): share-sheet
extension; themed app icons.

Each pass lands green (`swift build`, `swift run CoreChecks`, clean
`xcodebuild`) before the next begins; device deploy after the final pass.
