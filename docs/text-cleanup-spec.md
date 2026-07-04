# Text cleanup specification

## Scope

This document defines `TextCleanup.clean(_:)`, the deterministic stage that
normalizes pasted, shared, and imported text into clean reader input **without
rewriting prose**. It covers:

- whitespace and blank-line normalization;
- wrapped-line repair;
- numeric citation removal;
- standalone and inline URL handling;
- HTML entity decoding;
- high-confidence boilerplate, cookie, and share/navigation removal;
- image-caption removal;
- invisible/control-character removal;
- an inspectable record of every change.

It does not define tokenization, pacing, boundaries, sentence indices, phrase
chunking, rendering, or persistence. Word semantics belong to
[`tokenizer-spec.md`](tokenizer-spec.md).

**Status:** implemented for Pass 2 of
[`trance-pass-spec.md`](trance-pass-spec.md). `TextCleanup.clean` and its fixtures
are green, and cleanup is wired into the reader ingest path: `ReaderViewModel.load`
runs `clean(strip(raw))` once, then tokenizes and persists the cleaned prose, so
resume, recents, exports, and read-time all read debris-free text. The remaining
follow-up is the single-strip seam (see the integration note below); today
`Tokenizer.tokenize` re-strips the already-clean text, which is a correct but
wasteful no-op. It ships independently of tokenizer hardening. Cleanup is
`Foundation`-only. Unlike the tokenizer, this stage **uses `NSRegularExpression`**:
URLs, citations, and entities are naturally pattern-shaped, and anchored patterns
paired with idempotence fixtures keep the behavior deterministic and testable. The
tokenizer remains regex-free.

---

## Pipeline position

Cleanup runs **after** Markdown removal and **before** word tokenization, per the
roadmap:

```text
raw input
  -> Markdown.strip
  -> TextCleanup.clean(_:)
  -> Tokenizer.tokenize(_:)
  -> phrase chunking (later)
  -> reader rendering
```

Because `Markdown.strip` already resolves `[label](url)` to `label`, unwraps
emphasis, and drops heading/list/quote markers, cleanup receives **plain prose**.
It therefore does not re-handle Markdown link syntax; there is no
`removeMarkdownLinkSyntax` operation. Standalone URLs, HTML entities, boilerplate
lines, and paste debris survive `Markdown.strip` and are cleanup's responsibility.

### Integration note

`Tokenizer.tokenize(_:)` currently calls `Markdown.strip` internally, so stripping
must not happen twice. The integration change (a later PR, not part of authoring
this spec) should establish a single seam where the order above holds — for
example, strip once at import, run `clean` on the stripped text, persist the
cleaned result, and tokenize the cleaned text. `Markdown.strip` is idempotent, so
a transitional `clean(strip(raw))` fed to today's `tokenize` (which strips again)
is correct but wasteful; prefer the single-strip seam. Cleanup itself is a pure
function and imposes no ordering beyond "after strip, before tokenize."

---

## Contract

```swift
public struct CleanedText: Sendable, Equatable {
    public let text: String
    public let operations: [CleanupOperation]
    public let warnings: [CleanupWarning]
}

public struct CleanupOperation: Sendable, Equatable {
    public let kind: CleanupOperationKind
    public let original: String
    public let replacement: String
    public let reason: String
}
```

`TextCleanup.clean(_:)` returns the cleaned `text`, an ordered list of the
`operations` it applied, and any `warnings`. Every mutation is recorded so the
result is inspectable. `CleanupWarning` carries non-fatal advisories (for
example, "input appeared to be mostly a URL list"); its exact shape is
implementation-defined for v1 and may start empty.

Operation offsets are optional for v1. If offsets are added later, they must
reference the **original** input to `clean`, not the cleaned output.

Empty and whitespace-only input return empty `text` with no operations.

---

## Cleanup principles

1. **Preserve prose by default.** When uncertain, keep the text. The reader
   survives some junk; it cannot recover silently deleted meaning.
2. **Normalize structure, not ideas.** Allowed: collapse repeated spaces, repair
   wrapped lines, collapse runs of blank lines, decode entities. Never allowed:
   simplify a sentence, rewrite a paragraph, soften or intensify a claim,
   reorder, translate, or infer missing text.
3. **Remove only high-confidence debris.** Target obvious non-prose artifacts:
   standalone/inline URLs, bracketed numeric citations, exact-match newsletter
   and social boilerplate, cookie prompts, navigation labels, confidently marked
   image captions, and invisible control characters.
4. **Be idempotent.** `clean(clean(input).text).text == clean(input).text` for
   every input.

---

## Operation kinds

```swift
public enum CleanupOperationKind: Sendable, Equatable {
    case normalizeWhitespace
    case collapseBlankLines
    case repairWrappedLines
    case removeBracketCitation
    case removeStandaloneUrl
    case collapseInlineUrl
    case removeHtmlEntity
    case removeBoilerplateLine
    case removeCookiePrompt
    case removeShareNavigation
    case removeImageCaption
    case removeInvisible
    case normalizeQuotes
    case normalizeDashes
    case preserve
}
```

`removeMarkdownLinkSyntax` from earlier drafts is intentionally absent: cleanup
runs after `Markdown.strip`, which already removes link syntax. `normalizeQuotes`
and `normalizeDashes` are optional in v1 (see below). `preserve` records a
deliberate non-removal for a false-positive fixture.

### Ordering

Apply operations in a fixed order so the result is deterministic and idempotent:

1. `removeInvisible` (zero-width, soft hyphen, BOM; non-breaking space → space)
2. `removeHtmlEntity`
3. line-level removals (`removeStandaloneUrl`, `removeBoilerplateLine`,
   `removeCookiePrompt`, `removeShareNavigation`, `removeImageCaption`)
4. inline substitutions (`removeBracketCitation`, `collapseInlineUrl`)
5. `repairWrappedLines`
6. `normalizeWhitespace` (horizontal collapse, edge trims)
7. `collapseBlankLines`

Whitespace normalization runs last so earlier removals cannot strand double
spaces or empty lines.

---

## Whitespace rules

- **Collapse horizontal whitespace.** Repeated spaces and tabs inside a line
  become a single space. `alpha␠␠␠␠beta` → `alpha␠beta`.
- **Trim line edges.** Strip leading and trailing whitespace from each line.
- **Trim document edges.** Strip leading and trailing whitespace from the whole
  document.
- **Preserve paragraph breaks; collapse excess.** One or more blank lines mean a
  paragraph separation. Collapse runs of three or more newlines to exactly two.

---

## Wrapped-line repair

Join a line break inside a paragraph only for a **confident soft wrap**: the
continuation line begins with a lowercase letter (mid-sentence continuation), the
previous line has no terminal punctuation, and neither line is a list.

```text
This sentence was copied from
a narrow column and continues.
```

becomes:

```text
This sentence was copied from a narrow column and continues.
```

Do **not** repair when:

- the continuation line does **not** begin with a lowercase letter — an uppercase
  or digit start is treated as a fresh line, which is what keeps
  `Before` / `After` (left behind after a removed URL line) from fusing;
- the previous line ends in terminal punctuation (`.`, `!`, `?`, `…`, or `:`,
  looking through trailing closers) — those are separate sentences or lead-ins;
- either line is list-like (starts with `-`, `*`, `•`, or `N.` / `N)`).

The lowercase-continuation rule is deliberately conservative — it follows the
"when unsure, keep the break" principle and accepts the miss where a wrapped line
legitimately continues with a capitalized word. Headings are not separately
detected; after `Markdown.strip` they are ambiguous, and in practice a following
blank line already separates them. Repair joins with a single space and never
introduces or removes hyphenation.

---

## Citation removal

Remove standalone bracketed **numeric** citations and compact runs:

```text
This is supported by research [1].      -> This is supported by research.
This is supported [1][2][3].            -> This is supported.
This is supported [1, 2, 7].            -> This is supported.
```

Remove the bracket and any single space that would otherwise sit before the
sentence's terminal punctuation, so no double space or floating space remains.

Do **not** remove non-numeric bracketed text — it may be meaningful:

```text
The command [build] failed.             -> unchanged
```

Do **not** remove parenthetical author-year citations in v1; they can carry
meaning and are not reliably debris:

```text
(Smith, 2020)        -> unchanged
(Smith et al., 2021) -> unchanged
```

---

## URL rules

- **Standalone URLs** (a line that is only a URL) are removed entirely,
  including the now-empty line.

  ```text
  Before
  https://example.com/report
  After
  ```
  becomes:
  ```text
  Before
  After
  ```

- **Inline URLs** embedded in a sentence are replaced with the literal token
  `[link]`, preserving the surrounding prose:

  ```text
  Details are at https://example.com/report and will be updated.
  ```
  becomes:
  ```text
  Details are at [link] and will be updated.
  ```

- **Emails are preserved** in v1 — they may be meaningful in copied
  correspondence:

  ```text
  Send it to joe@example.com by noon.    -> unchanged
  ```

Match `http://`, `https://`, and bare `www.` hosts. Do not attempt to validate
or fetch. A "standalone" URL is a line whose trimmed content is entirely a single
URL (optionally wrapped in `<…>` angle brackets).

---

## HTML entities

Decode the common named and numeric entities; do not attempt full HTML parsing
in v1:

| Entity | Replacement |
|---|---|
| `&amp;` | `&` |
| `&lt;` | `<` |
| `&gt;` | `>` |
| `&quot;` | `"` |
| `&#39;` | `'` |
| `&nbsp;` | space |

Decode `&amp;` before other ampersand-bearing entities so a double-encoded
`&amp;lt;` does not partially resolve inconsistently across runs (idempotence).

---

## Boilerplate removal

Remove a line only when the **whole trimmed line** matches a frozen,
high-confidence set (case-insensitive). Never remove these phrases when embedded
in real prose.

Frozen boilerplate set (exact whole-line match):

```text
subscribe to our newsletter
sign up for our newsletter
advertisement
sponsored content
continue reading
read more
share this article
back to top
all rights reserved
privacy policy
terms of service
```

Preserved because it is prose, not a standalone line:

```text
The company changed its privacy policy after the incident.   -> unchanged
```

### Cookie prompts

Remove full lines matching the cookie-consent set:

```text
accept all cookies
reject all
manage preferences
manage consent
cookie settings
we use cookies to improve your experience
```

### Share / navigation

Remove isolated single-purpose navigation lines:

```text
facebook
twitter
linkedin
copy link
share
menu
search
home
skip to content
```

These are removed only as whole isolated lines, never inside prose.

---

## Image captions

Remove a line only when it begins with a strong caption marker (case-insensitive,
at line start, followed by content):

```text
Image:   Image 1:   Photo:   Caption:   Figure:
```

Example:

```text
Image: A chart showing revenue growth.
Revenue increased in Q2.
```
becomes:
```text
Revenue increased in Q2.
```

Preserve `Figure`/`Image` references **inside** prose:

```text
Figure 2 shows revenue growth.   -> unchanged
```

The distinction: a caption marker is the line's leading label followed by `:`;
an in-prose reference continues as a sentence.

---

## Invisible and control characters

Remove or replace common invisible/control characters:

- zero-width space (`U+200B`) — remove;
- soft hyphen (`U+00AD`) — remove;
- byte order mark (`U+FEFF`) — remove;
- non-breaking space (`U+00A0`) — replace with a normal space.

Do **not** remove emoji — they may be user-authored.

---

## Quote and dash normalization (optional in v1)

- `normalizeQuotes`: if enabled, `“ ”` → `"` and `‘ ’` → `'`. Must not corrupt
  apostrophes inside contractions.
- `normalizeDashes`: **skip in v1.** The tokenizer relies on `—`/`–` for clause
  pacing, so do not collapse em/en dashes to hyphens.

Recommendation: skip both in v1 unless shipped behavior already normalizes them.

---

## Required fixtures

Add to `Sources/CoreChecks/main.swift` in the same change as the implementation.
Each fixture asserts the cleaned `text`; representative fixtures also assert the
recorded `operations` kind.

| Input | Output |
|---|---|
| `␠alpha␠␠␠␠beta␠␠␠␠gamma␠` | `alpha beta gamma` |
| `alpha\n\n\n\nbeta` | `alpha\n\nbeta` |
| `This sentence was copied from\na narrow column and continues.` | `This sentence was copied from a narrow column and continues.` |
| `This is done.\nThis starts again.` | unchanged |
| `- first item\n- second item` | unchanged |
| `The result was significant [1].` | `The result was significant.` |
| `Backed by many [1][2][3].` | `Backed by many.` |
| `Backed by many [1, 2, 7].` | `Backed by many.` |
| `The command [build] failed.` | unchanged |
| `Before\nhttps://example.com/report\nAfter` | `Before\nAfter` |
| `Details are at https://example.com/report and will be updated.` | `Details are at [link] and will be updated.` |
| `Send it to joe@example.com by noon.` | unchanged |
| `Tom &amp; Jerry` | `Tom & Jerry` |
| `Main paragraph.\nSubscribe to our newsletter\nNext paragraph.` | `Main paragraph.\nNext paragraph.` |
| `The newsletter became the company's main product.` | unchanged |
| `We use cookies to improve your experience\nThe article starts here.` | `The article starts here.` |
| `Share\nThe story begins.` | `The story begins.` |
| `Image: A chart showing revenue growth.\nRevenue increased in Q2.` | `Revenue increased in Q2.` |
| `Figure 2 shows revenue growth.` | unchanged |
| `The company changed its privacy policy after the incident.` | unchanged |

### Idempotence

For every fixture:

```swift
let once = TextCleanup.clean(input).text
let twice = TextCleanup.clean(once).text
// once == twice
```

---

## Implementation sequence

1. Add `CleanedText`, `CleanupOperation`, `CleanupWarning`, and
   `CleanupOperationKind` in `Sources/SkimCore/TextCleanup.swift`.
2. Implement `TextCleanup.clean(_:)` with the fixed operation order above.
3. Implement invisible-character and HTML-entity passes.
4. Implement line-level removals (standalone URL, boilerplate, cookie, share,
   caption) against the frozen sets.
5. Implement inline substitutions (numeric citation, inline URL → `[link]`).
6. Implement wrapped-line repair with its non-repair guards.
7. Implement whitespace and blank-line normalization last.
8. Add the full fixture matrix and idempotence checks to
   `Sources/CoreChecks/main.swift`.
9. Run `swift build` and `swift run CoreChecks`.
10. Run the relevant Xcode build.

Wire cleanup into the reader pipeline (after `Markdown.strip`, before
`Tokenizer.tokenize`) only after the fixtures pass, and follow with an
end-to-end pass over realistic messy pasted text.

---

## Acceptance criteria

This spec is satisfied when:

- cleanup is deterministic and idempotent;
- prose is preserved by default and every removal is recorded in `operations`;
- high-confidence debris (standalone/inline URLs, numeric citations, frozen
  boilerplate/cookie/share/caption lines, invisible characters) is removed;
- URLs no longer stream as RSVP potholes and numeric citations no longer stream
  word by word;
- tokenizer behavior changes only through cleaner input;
- phrase chunking remains out of scope.
