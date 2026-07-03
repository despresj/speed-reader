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

---

## Skim — Phrase Chunking + Text Cleanup: Unified Implementation Spec

**Status:** final, implementation-ready. Every disagreement between the three chunking designs is resolved below; an implementer never chooses.

**The two fences, restated as invariants:**

1. **Honest WPM.** `chunk.delayMultiplier = Σ member.delayMultiplier` and chunks partition the word stream, so total read time at N wpm is *identical* (to float associativity) to word mode: ≈ wordCount × 60/N plus the same rhythm overhead as today. Pinned by CoreChecks. No density discounts, no floors, ever.
2. **Calm instrument.** Zero user-facing knobs. Every constant below is a frozen decision, not a setting. Rhythm lands where meaning lands: a comma is a beat, a period a rest, a paragraph an inhale — now at the end of the fixation that contains them. Degradation on hostile pastes is always *toward today's word mode*, never toward chaos.

### Pipeline

```
raw clipboard text
  → Markdown.strip                 (existing, unchanged)
  → TextCleanup.clean              (NEW — §0)
  → Tokenizer.tokenize             (word tokens; §B hardening lands inside it)
  → Chunker.chunk                  (NEW — §A; word tokens → phrase tokens)
```

One canonical production entry point so exporters can never drift from the reader:

```swift
extension Tokenizer {
    /// THE production pipeline. `tokenize(_:)` alone remains the word-mode
    /// ground truth for CoreChecks and the chunker's input.
    public static func tokenizePhrases(_ text: String) -> [ReadingToken] {
        Chunker.chunk(tokenize(text))
    }
}
```

`Tokenizer.tokenize` integrates cleanup with one line (Tokenizer.swift:30):

```swift
let paragraphs = paragraphize(TextCleanup.clean(Markdown.strip(text)))
```

Chunking is a **separate pure fold**, not a tokenizer rewrite (all three designs agree; unanimous). Word mode stays the auditable base, each stage tests independently, and the honest-WPM proof is a one-line partition identity. New files: `Sources/SkimCore/TextCleanup.swift`, `Sources/SkimCore/Chunker.swift`, `Sources/SkimCore/FunctionWords.swift`. Foundation only, Swift 6, no UI imports.

---

### §0 — TextCleanup (debris pass)

*Runs after `Markdown.strip`, before `paragraphize`. Deletes or collapses mechanical junk; never rewrites prose. Governing rules, in precedence order: (1) when in doubt, KEEP; (2) never rewrite prose; (3) deterministic character walks and enumerated sets only — no regex where a walk is clearer, no NaturalLanguage, no knobs; (4) idempotent: `clean(clean(x)) == clean(x)`, pinned as a CoreChecks property; (5) debris is removed before tokenization so it never enters the token stream, the word count, or `ReadTimeEstimate` — WPM honesty by construction.*

**Phase A — character normalization** (single `Character → Character?` pass):
- A1: `\r\n`, `\r` → `\n` (self-contained even though Markdown.strip also does it).
- A2: remove invisibles U+200B, U+FEFF, U+2060, U+180E. **KEEP U+200D (ZWJ — emoji sequences) and U+200C (ZWNJ — Persian/Arabic).** Rationale: ZWSP is not Unicode `White_Space`, survives the tokenizer split, and silently corrupts `coreLength`, ORP indexing, and PivotFit width.
- A3: delete soft hyphen U+00AD.
- A4: space variants → U+0020: NBSP, U+202F, U+2007, U+2000–U+200A, U+3000, tab.
- A5: enumerated lookalike map only: U+2011→`-`, U+2015→`—`, U+2212→`-`, U+02BC/U+2032→`’`, U+201B→`‘`, U+201F→`“`. **Never** convert curly↔straight quotes, never touch em/en dashes, guillemets, backticks.

**Phase B — line rules** (a line is kept verbatim or deleted whole; interiors never edited):
- B1 boilerplate: remove iff the line's *normalized form* (trim → strip one trailing decoration run `. : ! … » → ›` and leading bullet glyphs → lowercase) is an **exact member** of the enumerated set (`advertisement`, `sponsored`, `subscribe`, `subscribe now`, `sign up`, `sign up for our newsletter`, `follow us`, `share this article`, `read more`, `continue reading`, `related articles`, `recommended for you`, `most popular`, `skip to content`, `listen to this article`, `leave a comment`, `view comments`, … full set frozen in code). Never substring/prefix/fuzzy; normalized line must be ≤ 8 words. `“Follow us,” she whispered, “or die here.”` is kept.
- B2 credits (both sub-rules require ≤ 12 words): (a) label-prefixed, case-insensitive `photo:`, `image:`, `credit:`, `photo by `, `illustration by `, `photo courtesy `, `getty images` line-initial, `ap photo/` → remove. `Source:` deliberately excluded. (b) wire-agency suffixed: contains `Getty Images` / `AP Photo` / `AFP via Getty` / `/Reuters` / `/AP` / `/Associated Press`, **and** agency adjacent to a `/`, **and** line does not end with a sentence terminator. `Chip Somodevilla/Getty Images` removed; `He later sold the archive to Getty Images.` kept.
- B3 wrapped-word heal (runs after B1/B2): line *i* ends `letter` + ASCII `-`, line *i+1* non-blank and starts lowercase → join, delete the hyphen (`under-\nstanding` → `understanding`). Do NOT heal when: fragment is a single letter or contains a digit; next line starts uppercase/digit/punctuation; char before hyphen is a hyphen. Accepted tradeoff (documented in a CoreChecks case): a compound wrapped at its real hyphen loses that hyphen — rare in clipboard text; streaming `under-`/`standing` on every PDF paste is common and worse.

**Phase C — inline rules:**
- C1 bracketed citations: strip `[…]` pairs (non-nested) plus one preceding space iff the interior is: 1–4 ASCII digits; digits joined by `,`/`-`/`–`/spaces; `note`/`n` + digits; `[a]`-style single lowercase letter immediately preceded by a non-space; or exact strings `citation needed`, `clarification needed`, `according to whom?`, `when?`, `who?`, `dubious – discuss`, `edit`. **KEEP** `[sic]`, `[emphasis added]`, `[T]he`-style alterations, `[…]`/`[...]`, empty `[]`, anything ≥ 30 chars.
- C2 URL collapse, per whitespace-delimited chunk: peel a trailing run of the tokenizer's own closers/enders and remember it; classify the remainder — scheme URL (`http(s)://`) → host with `www.`/userinfo/port dropped, lowercased; `www.` URL → same; bare domain with path/query debris and final label in the enumerated TLD set (`com org net edu gov io co ai dev app me info us uk ca de fr au nz`) → domain; **clean bare domain untouched** (this is what makes C2 idempotent); `mailto:`/emails untouched; everything else untouched. Re-append the peeled punctuation: `(see https://x.com/foo).` → `(x.com).` Character-walk host parser, no `URLComponents`.

**Phase D — whitespace last:** space runs → one; trim line-trailing whitespace; 2+ blank lines → one; drop leading/trailing blank lines; a line emptied by C1/C2 becomes a blank line and folds into paragraph handling.

**Tokenizer/chunker interaction (verified):** `trailingPunctuation` only scans trailing chars, so the interior dot in `nytimes.com` never bumps `sentenceIndex`; a real trailing `.` survives the peel/re-append and paces normally. Collapsed domains classify **code-ish** in §A (internal `.` with alphanumerics both sides) → they stand alone in the chunk stream, exactly right. The 80-char URL that used to hit PivotFit's floor mostly stops existing.

**API** (all public — CoreChecks precedent): `TextCleanup.clean(_:)` as the only production entry, plus per-phase functions (`normalizeCharacters`, `removeJunkLines`, `healWrappedWords`, `stripCitations`, `collapseURLs`, `normalizeWhitespace`) and predicates (`isBoilerplateLine`, `isCreditLine`, `readableForm(ofURLChunk:)`) exposed for table-driven CoreChecks.

**Out of scope, permanently for v1:** article extraction, footnote bodies, de-duplication, smart quotes, emoji removal, locale/ML anything, summarization.

---

### §A — Phrase chunking (`Chunker`)

#### A.1 Constants (frozen decisions)

| Constant | Value | Why |
|---|---|---|
| `maxWords` | 4 | reached only via function-word clings or name runs |
| `maxContentWords` | 2 | two content words is one comfortable fixation; three reads as a line |
| `charBudget` | 16 | joined chunk text incl. spaces; fits the 44pt base inside iPhone safe width with zero shrink for ≥95% of chunks |
| `standaloneLength` | 13 | core chars at which a word always stands alone (PivotFit territory) |
| `peelCap` | 2 | max tokens popped by the dangling repair (bounded progress) |
| `fallbackDensity` | 0.35 | per-paragraph standalone fraction that degrades that paragraph to word mode |
| `peelCap` overflow note | — | a re-opened chunk (`carry + host`) may rarely exceed `charBudget`; emit as-is, PivotFit absorbs; pinned by a fuzz fixture |

#### A.2 Word classes

**`FunctionWords`** — one frozen lowercase `Set<String>` in `FunctionWords.swift`, matched against the word with edge openers/closers stripped, lowercased. Union of the designs' lists (articles/determiners; prepositions; conjunctions/complementizers incl. `that`, `what`, `than`; pronouns; auxiliaries/copulas incl. `not`). ~95 entries, frozen in code with the category comments.

**`isClingy(w)`** (never ends a chunk when avoidable; binds forward):
```
isClingy(w) = FunctionWords.contains(strippedLower(w))
           || isTitleAbbreviation(w)        // "Dr.", "Gen." — §B title set
           || isInitialOrAcronym(w)         // ^([A-Z]\.)+$ after edge strip
```

**`isNameLike(w)`**: first core char is an uppercase letter AND w is not the first token of its sentence (sentence-initial caps are uninformative). Initials and title abbreviations count as NameLike.

**`isStandalone(w)`** — always a 1-word chunk; never merges, and breaks the chunk before it:

| Rule | Test |
|---|---|
| long word | `coreLength(w) >= 13` |
| complex number | existing `isComplexNumber` (no unit binding — **decided**: `3.2` + `GB` stay two tokens; the 'standalones never merge' invariant stays absolute) |
| internal dash | existing `hasInternalDash` (`Wait—really` stands alone with its 1.4 beat — **decided** over hosting neighbors) |
| URL/code-ish | contains `://`, or prefix `www.`, or `@` with letters both sides, or internal `/`, or internal `.` flanked by alphanumerics (known abbreviations/initials exempt via `!isClingy` guard), or any of `` { } [ ] < > = ; ` $ \ | ~ ^ `` , or `_`, or a `(…)` pair with content |
| pure emoji/symbol | core length 0 AND contains a symbol/emoji scalar (mixed `great🎉` is a normal word) |
| strong RTL | any scalar in 0x0590–0x08FF, 0xFB1D–0xFDFF, 0xFE70–0xFEFF (bidi inside a multi-word chunk scrambles display; one token is safe) |

**Zero-core cling** (bare `—`, `•`, stray `*` with no emoji scalar): never ends a chunk, never joins as a tail — clings forward onto the next word; paragraph-final it emits alone.

#### A.3 Hard boundaries — a chunk NEVER crosses

1. `boundary != .none` on a member (clause/sentence/paragraph verdict, §B/§E) — the punctuated word is always chunk-final. This is what makes §C's sum rule legal.
2. A `sentenceIndex` or `paragraphIndex` change (belt-and-suspenders).
3. A standalone token on either side.
4. `maxWords` / `charBudget`.

#### A.4 Algorithm (single greedy pass, one-token lookahead, O(n))

```
chunk(words):
  out = []
  for paragraph in slicesByParagraphIndex(words):
    if standaloneDensity(paragraph) >= 0.35:
      out += paragraph, renumbered           # local word-mode fallback
      continue
    cur = []; carry = []
    for t in paragraph tokens (consuming carry first):
      if coreLength(t)==0 and not emoji:  attach cling-forward; continue
      if isStandalone(t): flush(cur); emit([t]); continue
      if cur.isEmpty or canExtend(cur, t): cur.append(t)
      else:
        carry = peel(cur)                    # pop <= 2 trailing tokens while
                                             #   (isClingy(last) or (isNameLike(last) and isNameLike(t)))
                                             #   and last.boundary == .none and cur.count > 1
        flush(cur); cur = carry + [t]
      if t.boundary != .none: flush(cur)     # punctuated word closes its chunk
    flush(cur)

canExtend(cur, next):
  next.sentenceIndex == cur[0].sentenceIndex           # hard
  and next.paragraphIndex == cur[0].paragraphIndex     # hard
  and cur.last.boundary == .none                       # hard
  and !isStandalone(next)                              # hard
  and cur.count + 1 <= 4                               # hard
  and joinedChars(cur) + 1 + chars(next) <= 16         # hard
  and ( allNameLike(cur) and isNameLike(next)          # name-run override
        or contentCount(cur) + (isContent(next) ? 1 : 0) <= 2 )
```

Termination: every emit produces ≥ 1 token; the peel is capped at 2 and popped tokens open the next chunk. `It is what it is.` → `It is` · `what it is.` (all-function sentence: peel cap allows the bounded ending-on-function; documented CoreChecks case).

**Worked examples (all pinned in CoreChecks):**
- Doctrine line → `The instrument` · `supplies` · `the discipline` · `so the mind` · `can supply` · `the attention.`
- `the quick brown fox jumps over the lazy dog.` → `the quick brown` · `fox jumps` · `over the lazy` · `dog.`
- `Dr. J. K. Rowling wrote it` → `Dr.` · `J. K. Rowling` · `wrote it` (char budget splits at a whole-name boundary; peel prevents ending on an initial)
- `He said, "wait for me."` → `He said,` · `"wait for me."`
- `costs 1,000,000 dollars` → `costs` · `1,000,000` · `dollars`
- `see https://example.com/x now` → (post-cleanup) `see` · `example.com` · `now`
- Legalese `pursuant to Section 4(a)(ii) thereof,` → `pursuant to Section` blocked at budget → `pursuant to` · `Section` · `4(a)(ii)` (standalone) · `thereof,`

#### A.5 Hostile-paste degradation (the robustness contract)

Two layers, both automatic, no classifier knob: (1) **local/emergent** — every code-ish/URL/long/numeric/dashed/RTL/emoji token stands alone and breaks its neighbors, so a URL-dense changelog degrades word-by-word *within* prose that still chunks; (2) **per-paragraph** — standalone density ≥ 0.35 emits that paragraph 1:1 (code blocks, flattened tables, log dumps), leaving surrounding paragraphs chunked. **Decided:** per-paragraph replaces the rhythm design's global 15% switch — no wholesale mode cliff. Worst case for any input is exactly today's word mode.

---

### §B — Sentence detection hardening (inside `Tokenizer`, same single pass)

One-token lookahead only (`words[wordIndex + 1]` — already materialized). The abbreviation set splits in two; **this fixes the live bug where `etc. The next sentence` never increments `sentenceIndex`.**

- `titleAbbreviations` (trailing `.` is NEVER a sentence end; multiplier 1.0): `mr. mrs. ms. dr. prof. st. sr. jr. gen. sen. rep. gov. capt. sgt. lt. col. rev. hon. mt. vs. fig. no. vol. ch. sec. pp. ed. cf.`
- `midAbbreviations` (sentence end IFF paragraph-final OR next core-initial char, after skipping openers, is an **uppercase letter**): `etc. e.g. i.e. approx. est. incl. dept. inc. ltd. co. corp. misc. al. jan. feb. mar. apr. jun. jul. aug. sep. sept. oct. nov. dec.` (months live here; `Jan. 3` never breaks because a digit is not an uppercase letter).

Verdict table, evaluated top-down for a word whose closer-skipped trailing char is a terminator:

| # | Condition | Sentence end? | Multiplier |
|---|---|---|---|
| 1 | trailing `!` or `?` | **yes, always** | 2.0 |
| 2 | initial/acronym pattern — edge-stripped core matches `(uppercase letter + '.')+` (`J.`, `U.K.`) | **never** | 1.0 |
| 3 | title abbreviation | **never** | 1.0 |
| 4 | mid abbreviation | iff paragraph-final or next starts uppercase letter | 2.0 when end, else 1.0 |
| 5 | trailing ellipsis (`…` or run of 2+ `.`, normalized for classification only) | iff paragraph/text-final or next starts uppercase letter | **2.0 always** (an ellipsis is a rest even mid-sentence); boundary = `.clause` when not a sentence end |
| 6 | plain `.` | iff paragraph-final OR next core-initial char is an uppercase letter **or a digit** | 2.0 when end; **1.4 clause beat** when not (a period that didn't end the sentence is still a beat) |

**Resolved conflict (digits as sentence-start evidence):** digits count for *plain words* (rule 6: `He left. 40 people stayed` breaks correctly) but not for abbreviations (rules 3–5 check uppercase letters only: `No. 5`, `Jan. 3`, `approx. 40` never break). Asymmetric-cost rationale: a false split corrupts `sentenceIndex` and jolts twice; a missed split costs one rest.

**Initials are a flat never** (rule 2) — the lowercase-lookahead variant is rejected: `vitamin C. Next` mis-grouping costs one missed rest; splitting `J. K. Rowling` costs two jolts and breaks sentence replay. Decimals need no rule (`3.14` has no trailing period; `3.14.` hits rule 6). `end.")` unchanged via existing closer-skip. Accepted, documented misses: sentences opening with lowercase brands (`. iPhone sales…`) degrade to a 1.4 beat; a title abbreviation genuinely ending a sentence (`…met the Gen.`) is missed.

Every table row lands as a CoreChecks assertion in the same change (CLAUDE.md convention).

---

### §C — Chunk pacing

**The rule is plain sum:** `chunk.delayMultiplier = Σ member.delayMultiplier`. Nothing else.

Legality: §A.3 forces any word carrying a pause component (clause 1.4 / sentence 2.0 / paragraph 2.8) to be chunk-final, so non-final members only carry {1.0, 1.15} and the final member's max-composed multiplier rides in whole. Pauses land exactly where they do today — after the punctuated word, now at a fixation boundary, which is also where the paragraph breath and sentence haptic belong.

**Honest-WPM identity (not approximation):** chunks partition the word-token indices, so `Σ_chunks Σ_members mᵢ = Σᵢ mᵢ` — chunked total time ≡ word-mode total time for every text and every band, and `ReadTimeEstimate` (a straight multiplier sum) returns the same seconds with **zero changes**. Pinned: `expectClose(Σ chunked multipliers, Σ word multipliers, tol: 1e-9)` on a punctuation-and-paragraph-rich fixture plus a `SeededRNG`-shuffled property check.

**Rejected, permanently:** the edge-case design's pace+extra decomposition (diverges 0.15 on long-words-at-boundaries, trading a float-exact identity for a 2%-tolerance one — worse invariant, more machinery); sub-linear density factors and per-chunk floors (both are WPM lies and drift toward the speed-reading gimmick the philosophy fences off). The calm *is* the linear sum: `so the mind` holds 3 beats (~514ms at 350wpm) — one finished fixation; ~2.4× fewer transitions is the slot-machine fix, at unchanged total time.

---

### §D — Pivot / ORP for chunks

**Anchor = the ORP letter of the first content word** (first member whose stripped-lowercase core ∉ `FunctionWords`; word 0 for all-function chunks). Leading clitics sit left of fixation at low acuity — exactly natural reading. Rejected: chunk-center (focal x wanders; kills ORP's documented "still point" contract), longest-word, per-word micro-pivots.

**The pivot is precomputed by `Chunker` into `token.pivotIndex`** (Character-array coordinates matching `ORP.split` indexing): `Σ_{j<w}(chars(wordⱼ)+1) + ORP.pivotIndex(for: word_w)`. This keeps `FunctionWords` out of `ORP` and makes view/exporter adoption one expression. ORP gains one additive overload; existing API untouched:

```swift
extension ORP {
    /// Split around an explicit pivot index (chunk tokens). Single-word tokens
    /// with pivotIndex == nil use the existing rule unchanged.
    public static func split(_ text: String, pivotIndex: Int) -> Pivot
}
// call site: ORP.split(token.text, pivotIndex: token.pivotIndex ?? ORP.pivotIndex(for: token.text))
```

**Rendering constants (mode-fixed, not knobs), decided:** the phrase stream renders **every** token — chunks, standalones, and fallback-paragraph words alike — at **one fixed base of 44pt** (min 30 unchanged), with **anchorX = 0.40 × surface width**. One size, period: the two-tier sizing in the other designs (52pt standalones next to ~41pt chunks) is exactly the size wobble the solver hierarchy exists to prevent. At ~0.48em average SF glyph width, the 16-char budget ⇒ ~338pt worst case inside the ~353pt safe width, so ≥95% of chunks render with zero shrink; first-content-word anchoring makes `after` the heavy side and 40/60 room matches that asymmetry. **`PivotFitSolver` is unchanged** — it remains the silent safety net for peel-overflow outliers and standalone monsters (URLs, compounds, JSON), whose worst case is identical to today.

---

### §E — Data model + API

**`ReadingToken` — three additive fields, all defaulted, every existing init/call site and CoreChecks fixture compiles unmodified:**

```swift
public enum Boundary: Sendable, Equatable { case none, clause, sentence, paragraph }

// appended to ReadingToken with defaults in init:
public let wordCount: Int        // = 1   — words merged into this token
public let boundary: Boundary    // = .none — the tokenizer's pause verdict (paragraph > sentence > clause)
public let pivotIndex: Int?      // = nil — chunk anchor (Character index); nil → existing ORP rule
```

Each field has a named consumer: `wordCount` → true word counts, resume ordinals, word-budgeted context windows; `boundary` → the chunker's boundary rules (the tokenizer's verdict travels on the token — **decided** over the edge-case design's internal parallel-array plumbing) and the permanent ban on `delayMultiplier >=` threshold logic in app code (a 3-word chunk sums to 3.0 with no sentence end; grep verified none exists today — the field keeps it that way); `pivotIndex` → §D rendering.

Chunk construction: `text` = members joined with a single space; `delayMultiplier` = sum; `sentenceIndex`/`paragraphIndex` = first member's (uniform by construction); `boundary` = last member's; `tokenIndex` renumbered 0…k; fresh `id`.

**API:**

```swift
public enum Chunker {
    /// Fold word tokens into 1–4-word phrase tokens. Deterministic, greedy,
    /// zero configuration. Chunking an already-chunked stream is unsupported.
    public static func chunk(_ words: [ReadingToken]) -> [ReadingToken]
    /// Map a persisted word ordinal (Σ wordCount before the reading position)
    /// to the chunk index containing it. Clamped; empty → 0.
    public static func tokenIndex(forWordOrdinal ordinal: Int, in tokens: [ReadingToken]) -> Int
    /// Exposed for CoreChecks threshold pins.
    public static func standaloneDensity(_ paragraph: ArraySlice<ReadingToken>) -> Double
}
public enum FunctionWords {
    public static let all: Set<String>
    public static func isFunction(_ word: String) -> Bool   // edge-strip + lowercase inside
}
```

**No mode enum, no user setting.** Phrases are how Skim reads prose; word display is the automatic per-paragraph fallback tier of the same pipeline, never a toggle. `ReadingMode` (precisionHeld/cruise) is an unrelated axis — untouched.

---

### §F — Migration (every consumer, exact adaptation)

| Call site | Impact | Action |
|---|---|---|
| `ReadingContext.proseMap`/`fullText` + Threadline (`App/Threadline.swift:285`) | **None** — chunk texts are single-space joins, so the assembled prose is character-identical to word mode (pinned); ranges widen to the phrase, matching what the surface showed. Sentence-bounds walk (`:349–356`) still sees contiguous monotone `sentenceIndex` runs | none |
| `SentenceNavigation` replay/skip | runs stay contiguous; grace of 2 chunks ≈ 4–5 words — slightly more generous replay, on-philosophy | **keep `graceWindow = 2`** (decided; 2-vs-1 dispute resolved by "recovery is generous") |
| `ReadTimeEstimate` (`ReaderViewModel.swift:349–364`, ResumeView) | identical seconds (§C identity) | none + CoreChecks pin |
| `ReaderViewModel.wordCount` (`ReaderViewModel.swift:302`) → QuestionPlan, comprehension (`:581–602`, `ReviewView.swift:69,142,157,194`) | **breaks** (would report chunk count) | `tokens.reduce(0) { $0 + $1.wordCount }` — one line fixes all downstream consumers |
| **Persisted position** (`SkimStore`; `ReaderViewModel.swift:594,633,1060–1062`; `ResumeView.swift:298–299`) | **breaks** (chunk index ÷ word count skews; old saves land wrong) | **Decided: word-ordinal persistence** (exact, not clamp, not sentence-snap): persist `lastWordOrdinal = Σ wordCount(tokens[..<index])`; on load, `Chunker.tokenIndex(forWordOrdinal:in:)`. Legacy `lastTokenIndex` values ARE word ordinals by construction — the migration is a rename plus the mapping call; clamp remains the final guard. `ResumeView` progress = `lastWordOrdinal / (wordCount − 1)` |
| `ReadingContext.window` (`ReaderViewModel.swift:321`, ReadingView `before: 4, after: 4`) | window ≈ 2× wider in words | **Decided:** add a word-budgeted variant accumulating `wordCount` until the budget is met; call sites keep their numbers and the visual width is unchanged (rejected: retuning raw constants to 2/2 — word-budget keeps the constants meaningful) |
| Scrubber `ReadingNavigation.jumpTarget` flicks (`ReaderViewModel.swift:1153`) | a flick now covers ~2.5× the words | halve flick-distance constants at the call site; feel-tune on device |
| Progress checkpoint `currentIndex % 50` (`ReaderViewModel.swift:1207`) | 50 chunks ≈ 125 words between saves | change to `% 20` |
| `ResumeGlide` | span now ~2.5× the words | shorten span constant (8 → 4); feel-tune |
| Playback loop + paragraph breath (`ReaderViewModel.swift:1177–1200`, keyed on `paragraphIndex` change) | semantics-preserving | none |
| Haptics | event-keyed, not multiplier-keyed (grep-verified) | none; any future pause-kind logic uses `token.boundary` |
| PivotWord / ReadingView (`:1270–1316`) | pivot source + base size | `ORP.split(text, pivotIndex:)` fallback expression; base 52 → 44, anchorX → 0.40 × width; solver untouched |
| Exporters (`ExportViewModel.swift:35`, `GIFExporter.swift:29`, `VideoExporter.swift:40`, `FrameRenderer`, `ExportTimeline.swift:90`) | tokenize independently today | switch to `Tokenizer.tokenizePhrases`; durations already correct via the sum identity; `FrameRenderer` renders with the same pivot expression + 44pt base — exported clips show exactly what the surface showed |
| Comprehension check | consumes `fullText` — identical string | none |

#### CoreChecks additions (same change as the code)

1. TextCleanup: URL collapse (+ trailing-punct survival, email untouched, bare-domain nil), citation keep/strip table, boilerplate/credit yes/no table, wrap-heal cases, ZWSP removed / emoji ZWJ preserved, `clean∘clean == clean` idempotence, "debris never becomes tokens" end-to-end.
2. §B verdict table: one assertion per row, incl. `etc. The next` sentence-count fix, `J. K. Rowling wrote. Then…`, `No. 5`, `Jan. 3`, ellipsis both ways, `end.")`.
3. Chunk shape: every worked example in §A.4; hard-boundary property (no chunk spans a verdict/sentence/paragraph; ≤4 words) over fixtures; peel/dangling rules incl. `It is what it is.` termination; name cohesion; standalone isolation (URL, RTL, emoji, dash, number); per-paragraph 0.35 fallback (code paragraph 1:1 while neighbors chunk).
4. Invariants: `proseMap(chunked).text == proseMap(words).text`; multiplier-sum identity (1e-9) incl. `SeededRNG` property check; `Σ wordCount == word token count`; `tokenIndex(forWordOrdinal:)` round-trip.
5. Pivot: `pivotIndex` equals first-content-word ORP offset; all-function chunk anchors word 0; single-word chunks reduce to `ORP.pivotIndex`.

#### Build order (each stage green via `swift build && swift run CoreChecks` before the next)

1. **TextCleanup** + integration line + checks — ships alone, improves word mode today.
2. **Tokenizer §B hardening + `boundary` field** + checks — ships alone (fixes the `etc.` bug immediately).
3. **`ReadingToken` `wordCount`/`pivotIndex`** (defaulted, inert).
4. **`Chunker` + `FunctionWords` + `ORP.split(_:pivotIndex:)`** + full chunk suite — pure core, verified before any UI change.
5. **App flip** as one deployable change: `tokenizePhrases` everywhere (reader + exporters), the §F call-site edits (wordCount sum, word-ordinal persistence, window word-budget, flick/checkpoint/glide constants, 44pt/0.40 rendering) — device feel pass, then `scripts/deploy-device.sh` **only on green**.

#### The one-line test, applied

Phrase chunks hand attention back: fewer, meaning-shaped fixations; pauses still land on punctuation; debris never reaches the eye; total time unchanged to the float; nothing to configure; every hostile paste degrades to today's word mode. The instrument reads the way a good reader-aloud phrases — rhythm, not speed.
