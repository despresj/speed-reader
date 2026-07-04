# Skim

Skim is a clipboard-first reading instrument for iPhone. It delivers text at a
controlled cadence so the reader can focus on comprehension instead of scrolling
and self-pacing.

Copy or import text, then hold anywhere to read or double-tap for hands-free
Cruise. Slide vertically to change speed, flick horizontally to replay or skip a
sentence, and release or tap to return to the surrounding prose.

## Current capabilities

- Clipboard and manual text input.
- `skim://read` deep links and plain-text file imports.
- ORP-anchored word display with punctuation, long-word, number, and paragraph
  pacing.
- Hold-to-read, Cruise, whole-surface speed steering, and sentence navigation.
- Paused Threadline context, progress scrubbing, remaining-time estimates, and
  eased resume behavior.
- Local recents, resume positions, completion review, and an ideas scratchpad.
- Five system-aware color themes.
- MP4 and GIF export.
- Optional BYOK OpenAI comprehension checks.

Phrase reading is the main unfinished product capability. The current delivery
order is maintained in [docs/trance-pass-spec.md](docs/trance-pass-spec.md).

## Repository layout

```text
App/                  SwiftUI application, UIKit bridges, export, and services
Sources/SkimCore/     Pure reading, persistence, and comprehension logic
Sources/CoreChecks/   Dependency-free core verification executable
docs/                 Active documentation and historical design records
Package.swift         SwiftPM manifest for SkimCore and CoreChecks
project.yml           XcodeGen definition for the iOS application
```

The iOS target compiles `App/` and `Sources/SkimCore/` into one module. The
SwiftPM package keeps the core independently buildable on macOS.

## Documentation

Start with [docs/README.md](docs/README.md). It identifies the active roadmap,
focused implementation specs, product philosophy, and historical archive.

The original [rsvp_casual_reader_spec.md](rsvp_casual_reader_spec.md) is retained
as historical product context; it is no longer the implementation authority.

## Verify the core

```sh
swift build
swift run CoreChecks
```

`CoreChecks` is the repository's dependency-free assertion suite. Add matching
checks whenever core behavior changes.

## Build the iOS app

Requires Xcode and XcodeGen:

```sh
brew install xcodegen   # if needed
xcodegen generate
xcodebuild -project Skim.xcodeproj -scheme Skim \
  -destination 'generic/platform=iOS Simulator' build
```

Or open the generated project:

```sh
open Skim.xcodeproj
```

`Skim.xcodeproj` is generated and ignored. Edit `project.yml`, not the project
file.

Set `SKIM_SAMPLE` in the launch environment to preload text during development.

## Deploy to a paired iPhone

After a green build:

```sh
scripts/deploy-device.sh
```

The script regenerates the project, builds, installs, and launches only if the
device build succeeds. Over SSH, the login keychain may need to be unlocked
before code signing:

```sh
security unlock-keychain ~/Library/Keychains/login.keychain-db
```

List paired devices with `xcrun devicectl list devices`.
