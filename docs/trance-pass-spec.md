# The trance pass — remove trance-breakers before adding surfaces

> **Canonical roadmap.** Current documentation structure and shipped-state
> summary live in [`README.md`](README.md). Historical plans under
> `superpowers/` are not backlog.

Four passes, shipped in order. Passes 1–3 make the product match the promise in
`skim-product-philosophy.md`; pass 4 teaches the finished interaction. The test
for every change is simple: does it hand attention back, or quietly take it
away?

Explicitly out of scope: stats, streaks, reading goals, font pickers, AI
summaries, dashboards, and additional settings knobs.

---

## Status

| Pass | State | Notes |
|---|---|---|
| 1. Screen wake + time left | Shipped | Implemented with CoreChecks coverage. |
| 2. Text cleanup | Shipped | `TextCleanup.clean` and fixtures land in [`text-cleanup-spec.md`](text-cleanup-spec.md), wired into the reader ingest path (`ReaderViewModel.load`). The single-strip seam is a later cleanup. |
| 3. Phrase reading | Tokenizer shipped | `Tokenizer` emits explicit boundaries per [`tokenizer-spec.md`](tokenizer-spec.md); phrase chunking still needs its own final spec. |
| 4. First-read lesson | Planned | Starts only after phrase reading is validated on device. |

Tokenizer behavior is defined in [`tokenizer-spec.md`](tokenizer-spec.md). That
document covers word tokenization and sentence/boundary detection only. It does
not define text cleanup, phrase chunking, rendering, or app migration.

---

## Pass 1 · Keep the screen awake; answer “can I finish this?”

### Screen wake

Cruise has no touches, so iOS can dim and lock the phone while words are still
advancing. The screen must remain awake only during `.precisionHeld` and
`.cruisePlaying`, then immediately return to normal behavior in every parked or
completed state.

Implementation:

- `ScreenWake.shouldStayAwake(_:)` owns the pure state decision.
- `ReaderViewModel` applies that decision from the single `state` transition
  point.
- CoreChecks pins all `ReaderState` cases.

### Time left

The useful question is “can I finish this?”, not “which token number am I on?”

- `ReadTimeEstimate.remainingSeconds(tokens:from:wpm:)` sums paced durations
  from the current position.
- The scrubber shows approximate time left first and percentage second.
- The parked reader shows a quiet approximate time-left label.
- Active reading never shows a live countdown.

---

## Pass 2 · Clean mechanical paste debris

Add a deterministic core cleanup stage after Markdown removal and before word
tokenization. It may remove mechanical debris, but it must not rewrite prose.

Candidate responsibilities:

- normalize non-semantic whitespace and invisible characters;
- remove standalone URLs and replace inline URLs with `[link]`;
- remove tightly recognized numeric citation markers;
- remove exact-match newsletter, social, advertisement, and credit lines;
- repair unambiguous line wrapping.

The dedicated spec is [`text-cleanup-spec.md`](text-cleanup-spec.md): it holds the
complete rule tables, frozen match sets, operation ordering, idempotence
requirements, and false-positive fixtures. Partial lists or fuzzy prose rules are
not sufficient.

The cleanup contract is conservative:

1. When uncertain, keep the source text.
2. Never summarize or paraphrase.
3. Preserve typographic punctuation and meaningful Unicode.
4. Make cleanup idempotent.
5. Test both removals and intentional non-removals.

---

## Pass 3 · Read phrases instead of isolated words

Phrase reading should reduce visual churn without changing honest reading time.
Fresh prose uses short phrase units; dense or code-like paragraphs degrade
automatically toward word units. There is no user-facing mode or setting.

This pass consists of separate pieces:

1. Harden the existing word tokenizer and emit explicit boundaries. See
   [`tokenizer-spec.md`](tokenizer-spec.md).
2. Define and implement deterministic phrase chunking over word tokens.
3. Add phrase-aware pivot calculation and rendering.
4. Migrate every consumer of token indices and token counts to explicit word
   ordinals where user-visible progress or persistence is involved.
5. Switch the reader and exporters through one canonical production pipeline.

Phrase chunking must preserve these invariants:

- total paced duration is identical to the underlying word-token stream;
- no phrase crosses a tokenizer boundary, sentence, or paragraph;
- phrase text reconstructs the same cleaned prose as word tokens;
- word count, progress, persistence, scrubbing, exports, and idea captures retain
  word-based semantics;
- hostile input degrades locally and predictably toward word display;
- all constants are product decisions, not settings.

The chunking algorithm is intentionally not specified here. It needs a focused
spec with complete function-word sets, exact classification rules, unambiguous
budget behavior, full index migration, and worked fixtures before coding begins.

Definition of done includes device reading with at least a news article, dense
email, fiction passage, and code-adjacent paste.

---

## Pass 4 · Let the first read teach the interaction

Offer a bundled sample read of roughly 200 words on a true first launch. The
sample teaches holding, sliding, sentence replay, and paused context through the
text itself.

- Offer it as a quiet “Take your first read” action on the paste screen.
- Suppress the gesture overlay for the sample because the text is the lesson.
- Keep the sample on the normal production reading pipeline.
- Preserve the gesture overlay for users who begin with their own text.

---

## Delivery order

1. Ship and verify screen wake plus time left. **Complete.**
2. Finalize the cleanup spec, then implement cleanup with fixtures. **Complete**
   — `TextCleanup.clean` and its fixtures are green and wired into the reader
   ingest path: `ReaderViewModel.load` runs `clean(strip(raw))`, then tokenizes
   and persists the cleaned prose. The single-strip seam (dropping the tokenizer's
   internal re-strip) remains a later cleanup.
3. Implement [`tokenizer-spec.md`](tokenizer-spec.md) independently and keep word
   mode green. **Complete** — the tokenizer emits explicit boundaries with full
   CoreChecks coverage.
4. Finalize and implement phrase chunking in pure core.
5. Migrate app and export consumers in one deployable phrase-reading change.
6. Feel-test on device.
7. Add the first-read lesson.

Every implementation stage must pass `swift build`, `swift run CoreChecks`, and
the relevant Xcode build before the next stage begins.

---

## Deferred, not active backlog

These remain possible follow-ons after the trance work, but they are not part of
the current delivery sequence:

- native Share extension;
- PDF or Safari article extraction;
- themed MP4/GIF export;
- alternate themed app icons.

Accounts, cloud sync, streaks, leaderboards, reading goals, AI summaries, social
feeds, and broad settings expansion remain explicitly rejected by the product
philosophy.
