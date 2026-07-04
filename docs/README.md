# Skim documentation

This page is the documentation entry point. Documents are grouped by authority
so completed implementation plans do not masquerade as current backlog.

## Active documents

| Document                                                   | Purpose                                                                         |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------- |
| [`../README.md`](../README.md)                             | Current product summary, repository layout, and build instructions.             |
| [`skim-product-philosophy.md`](skim-product-philosophy.md) | Product principles and feature filter.                                          |
| [`trance-pass-spec.md`](trance-pass-spec.md)               | Canonical roadmap and delivery order. This is the only active backlog document. |
| [`text-cleanup-spec.md`](text-cleanup-spec.md)             | Focused implementation draft for paste-debris cleanup (Pass 2).                 |
| [`tokenizer-spec.md`](tokenizer-spec.md)                   | Focused implementation draft for tokenizer hardening.                           |
| [`shortcuts.md`](shortcuts.md)                             | Current iOS Shortcut and deep-link integration instructions.                    |

When active documents disagree, use this precedence:

1. shipped code and checks;
2. `trance-pass-spec.md` for roadmap and sequencing;
3. the focused spec for the component being changed;
4. `skim-product-philosophy.md` for product tradeoffs.

## Current product state

Shipped:

- clipboard, manual text, deep-link, and plain-text file input;
- word RSVP with ORP anchoring and punctuation-aware pacing;
- hold-to-read and hands-free Cruise;
- whole-surface speed steering and semantic sentence replay/skip;
- paused Threadline context, scrubber, remaining-time estimate, and resume glide;
- local recents, persisted positions, ideas, and completion review;
- five light/dark color themes;
- MP4 and GIF export;
- optional BYOK OpenAI comprehension checks with local persistence.

Active delivery sequence:

1. text-cleanup specification and implementation — done, wired into the reader ingest path;
2. tokenizer hardening from `tokenizer-spec.md` — done;
3. phrase-chunking specification and pure-core implementation;
4. word-ordinal migration and phrase-reading app/export adoption;
5. physical-device feel pass;
6. first-read sample lesson.

## Historical documents

[`superpowers/`](superpowers/README.md) records design and implementation
decisions that produced the current app. They are retained for rationale and
archaeology, not as executable plans or backlog.

The root [`../rsvp_casual_reader_spec.md`](../rsvp_casual_reader_spec.md) is the
original product brief. It remains useful context, but its feature lists,
constants, and build order have been superseded by the shipped product and the
active roadmap.

[`full-surface-and-themes-spec.md`](full-surface-and-themes-spec.md) is a shipped
design record. Its only explicit deferral is themed export, which is not on the
active roadmap.

## Maintenance rule

- Add new backlog only to `trance-pass-spec.md`.
- Give substantial implementation work one focused spec linked from the roadmap.
- When work ships, update the roadmap and this index in the same change.
- Mark implementation plans historical instead of leaving “pending” status text.
- Keep README and contributor guidance aligned with current gestures, speed
  ranges, build commands, and architecture.
