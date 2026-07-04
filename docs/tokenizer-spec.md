# Tokenizer hardening specification

## Scope

This document defines `Tokenizer.tokenize(_:)`, the word-token foundation used
by the reader. It covers:

- word splitting;
- pacing multipliers;
- clause, sentence, and paragraph boundaries;
- sentence and paragraph indices;
- deterministic handling of abbreviations, initials, decimals, ellipses, and
  closing punctuation.

It does not define text cleanup, phrase chunking, function-word grouping, phrase
pivots, rendering, persistence migration, or application UI.

**Status:** focused implementation draft; the rule tables are complete and await
acceptance. The implementation remains Foundation-only and does not use
`NaturalLanguage`, locale-sensitive segmentation, regular expressions, or
probabilistic rules.

---

## Contract

`Tokenizer.tokenize(_:)` returns one `ReadingToken` per whitespace-delimited
word after `Markdown.strip`.

For every output token:

- `text` preserves the stripped source word exactly;
- `tokenIndex` is contiguous and zero-based;
- `paragraphIndex` is contiguous and zero-based across non-empty paragraphs;
- `sentenceIndex` is monotonic and advances after each sentence boundary and at
  each non-empty paragraph transition;
- `boundary` records the strongest boundary after the token;
- `delayMultiplier` is the maximum applicable pacing multiplier.

Blank lines separate paragraphs. Other whitespace separates words. Empty and
whitespace-only input produces no tokens.

The tokenizer does not silently clean URLs, citations, boilerplate, Unicode
debris, or wrapped words. Those belong to a separate preprocessing stage.

---

## Data model

Add an explicit boundary to `ReadingToken`:

```swift
public enum Boundary: Sendable, Equatable {
    case none
    case clause
    case sentence
    case paragraph
}

public let boundary: Boundary
```

The initializer defaults `boundary` to `.none` so existing fixtures and callers
continue to compile while the tokenizer is migrated.

Boundary precedence is:

```text
paragraph > sentence > clause > none
```

`delayMultiplier` must not be used to infer a boundary. Future phrase tokens may
sum several ordinary word delays and therefore have multipliers greater than a
sentence pause without representing a sentence boundary.

---

## Pacing constants

| Condition | Multiplier |
|---|---:|
| ordinary word | 1.0 |
| more than 8 letters or digits | 1.15 |
| visually complex number | 1.15 |
| clause boundary or internal em/en dash | 1.4 |
| sentence boundary | 2.0 |
| paragraph boundary | 2.8 |

When several conditions apply, use the largest multiplier. Paragraph-final
punctuation therefore receives `2.8`, not an additive combination.

A visually complex number contains at least one digit and either:

- contains `,` or `.`; or
- contains at least six digits.

An internal dash is `—` or `–` with a letter or number on both sides. It creates
a clause boundary without splitting the word.

---

## Punctuation vocabulary

```swift
sentenceEnders = [".", "!", "?", "…"]
clauseEnders   = [",", ";", ":"]
closers        = ["\"", "'", "”", "’", "»", ")", "]", "}"]
openers        = ["\"", "'", "“", "‘", "«", "(", "[", "{"]
```

Sentence and clause classification looks through any trailing run of `closers`.
For example, `pipeline.")` is classified using its period while its text remains
unchanged.

Classification also strips surrounding `openers` and `closers` when comparing
an abbreviation or initial. It never changes the displayed token.

---

## Abbreviation classes

Comparison is case-insensitive except for the initial/acronym shape, which is
case-sensitive.

### Titles: never a sentence boundary

```text
mr. mrs. ms. dr. prof. st. sr. jr. gen. sen. rep. gov.
capt. sgt. lt. col. rev. hon. mt. vs. fig. no. vol. ch.
sec. pp. ed. cf.
```

These remain nonterminal even before an uppercase word because `Dr. Smith` and
`No. 5` are more common and more damaging to split than the accepted miss where
a sentence genuinely ends on a title abbreviation.

### Context abbreviations: boundary only before uppercase prose

```text
etc. e.g. i.e. approx. est. incl. dept. inc. ltd. co. corp.
misc. al. a.m. p.m. jan. feb. mar. apr. jun. jul. aug. sep.
sept. oct. nov. dec.
```

A context abbreviation is a sentence boundary when the next word's first core
character, after skipping openers, is an uppercase letter. At paragraph end,
the stronger paragraph boundary applies. A following digit is not
sentence-start evidence, preserving `Jan. 3`, `approx. 40`, and similar forms.

### Initials and acronyms: never a sentence boundary

After surrounding punctuation is stripped, a token is an initial or acronym
when it consists entirely of one or more repetitions of:

```text
uppercase letter + period
```

Examples: `J.`, `U.K.`, `U.S.A.`. Implement this with a deterministic character
walk. The accepted miss is a sentence that genuinely ends with an initial or
acronym.

---

## Sentence and boundary decision table

Evaluate the following rules in order. `next` means the next word in the same
paragraph.

| Priority | Condition | Boundary | Multiplier effect |
|---:|---|---|---:|
| 1 | paragraph-final token | `.paragraph` | 2.8 |
| 2 | closer-skipped token ends in `!` or `?` | `.sentence` | 2.0 |
| 3 | initial or acronym ending in `.` | `.none` | none |
| 4 | title abbreviation ending in `.` | `.none` | none |
| 5 | context abbreviation ending in `.` and next starts uppercase | `.sentence` | 2.0 |
| 6 | other context abbreviation ending in `.` | `.none` | none |
| 7 | ellipsis and next starts uppercase | `.sentence` | 2.0 |
| 8 | other ellipsis | `.clause` | 2.0 |
| 9 | other closer-skipped token ending in `.` | `.sentence` | 2.0 |
| 10 | closer-skipped token ending in `,`, `;`, or `:` | `.clause` | 1.4 |
| 11 | token contains an internal em/en dash | `.clause` | 1.4 |
| 12 | otherwise | `.none` | none |

Paragraph precedence means a final `Mr.` still receives `.paragraph` and the
paragraph breath even though it is not independently classified as a sentence.
The paragraph transition increments `sentenceIndex` exactly once.

Unlike the earlier trance-pass draft, an ordinary period always ends a sentence.
This preserves current behavior for lowercase starts such as `done. next` and
avoids silently weakening punctuation because capitalization is unreliable in
casual text and OCR output.

An ellipsis is either the single character `…` or a closer-skipped trailing run
of at least two periods. It always receives the 2.0 rest; lookahead determines
whether its boundary is `.sentence` or `.clause`.

---

## Sentence-index algorithm

Tokenize one paragraph at a time with one-token lookahead:

```text
sentenceIndex = 0

for each non-empty paragraph:
    lastEndedSentence = false

    for each word:
        classify boundary
        emit token with current sentenceIndex

        if boundary == sentence:
            sentenceIndex += 1
            lastEndedSentence = true
        else:
            lastEndedSentence = false

    if paragraph was non-empty and !lastEndedSentence:
        sentenceIndex += 1
```

A `.paragraph` boundary does not itself increment inside the word loop because
the paragraph transition performs that increment. This prevents double advances
for paragraph-final sentence punctuation while ensuring an unterminated
paragraph still starts the next paragraph in a new sentence.

---

## Required CoreChecks

### Existing behavior that must remain green

- whitespace splitting and contiguous token indices;
- punctuation preserved in token text;
- comma, semicolon, and colon clause pacing;
- period, exclamation, and question sentence pacing;
- punctuation behind closing quotes and brackets;
- paragraph separation and paragraph-final breath;
- long-word and complex-number pacing;
- internal em/en-dash pacing;
- decimals such as `3.14` not ending a sentence;
- terminal decimals such as `3.14.` ending a sentence;
- `done. next here` remaining two sentences.

### New boundary assertions

Each fixture must assert `boundary`, `delayMultiplier`, and `sentenceIndex` where
applicable:

| Fixture | Required result |
|---|---|
| `Mr. Smith arrived.` | `Mr.` is `.none`; `arrived.` is `.paragraph` |
| `etc. this continues` | `etc.` is `.none` |
| `etc. The next sentence` | `etc.` is `.sentence`; next token advances |
| `J. K. Rowling wrote. Then left.` | initials do not split; `wrote.` does |
| `No. 5 arrived.` | `No.` does not split |
| `Jan. 3 arrived.` | `Jan.` does not split |
| `Wait… this continues` | ellipsis is `.clause` with multiplier 2.0 |
| `Wait… This restarts` | ellipsis is `.sentence` |
| `end.") Next` | closer-skipped period is `.sentence` |
| `He left. 40 remained.` | ordinary period is `.sentence` before a digit |
| `done. next here` | ordinary period remains `.sentence` before lowercase |
| `alpha beta\n\ngamma` | `beta` is `.paragraph`; `gamma` has next sentence index |

As a repository audit, verify that application code does not infer pause kind
from multiplier thresholds.

---

## Implementation sequence

1. Add `Boundary` and the defaulted `ReadingToken.boundary` field.
2. Replace the single abbreviation set with the two complete sets above.
3. Add deterministic helpers for initials/acronyms, first-core-character
   lookahead, ellipsis recognition, and boundary classification.
4. Emit `boundary` and derive pacing from the decision table.
5. Add the complete CoreChecks matrix in the same change.
6. Run `swift build`, `swift run CoreChecks`, and the relevant Xcode build.

This work ships independently while the app still displays one word per token.
Text cleanup and phrase chunking must not be folded into the tokenizer change.
