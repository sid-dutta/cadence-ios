# Cadence

A workout and run logger for iOS, written in Swift 6 and SwiftUI.

Log sets with a live timer, get told the moment you set a personal record, log runs with pace, and watch your estimated one-rep max climb over time in Swift Charts. Everything works offline; sign in to sync with [cadence-api](https://github.com/sid-dutta/cadence-api) and your history follows you across devices.

## Architecture

The repo is a Swift package with two library targets plus a thin app target. The split is deliberate: the interesting code has no UI dependencies and is fully unit-tested, and the views compile for macOS as well as iOS so the whole package can be type-checked and tested from the command line without a simulator.

```
Sources/
├── CadenceCore/            Pure Swift. No SwiftUI, no UIKit.
│   ├── Models/             Workout, Exercise, ExerciseSet, Run — Codable value types
│   ├── Stats/              StatsEngine (Epley 1RM, PR detection, weekly buckets, streaks)
│   ├── Storage/            JSON file persistence with atomic writes
│   ├── Sync/               Last-write-wins merge + a typed API client
│   └── SampleData.swift    Seeded, deterministic demo history
├── CadenceUI/              SwiftUI views and the @Observable AppModel
└── App/Cadence/            @main — ten lines
Tests/CadenceCoreTests/     36 XCTest cases covering the core
```

**State.** One `@Observable` `AppModel` on the main actor owns the data and is the only thing that mutates it. Every mutation persists the full snapshot to disk, so an in-progress workout survives a crash or a force-quit.

**Persistence.** A single JSON document (`Application Support/Cadence/data.json`) written atomically. The models are plain `Codable` structs, which means the on-disk format *is* the wire format — the same bytes go to the server. SwiftData was the obvious alternative; it was skipped because the sync story is much simpler when the app's records are already value types with explicit `id`/`updatedAt`/`deletedAt`.

**Sync.** Last-write-wins keyed on `updatedAt`, with tombstones (`deletedAt`) so deletions propagate. The client pushes only records changed since its last sync and receives only what changed on the server. `SyncEngine.merge` is the same rule the server applies, so the result doesn't depend on which side goes first.

**Stats.** `StatsEngine` is a namespace of pure functions over `[Workout]` and `[Run]`: estimated 1RM (Epley), personal records with strict-improvement semantics, weekly aggregation with zero-filled gaps, and a streak that doesn't break until the week actually ends. The server has a line-for-line Python mirror in `app/stats.py`.

**Credentials.** The API token lives in the Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), not `UserDefaults`. Units and the server URL are ordinary preferences.

## Building

Requires Xcode 16 or later.

```bash
# Core + UI packages, and the unit tests — no simulator needed
swift build
swift test

# The iOS app. The .xcodeproj is committed; project.yml is the source of truth.
brew install xcodegen   # only if you edit project.yml
xcodegen generate
open Cadence.xcodeproj
```

Run on any iPhone simulator. Settings → *Load Sample Data* fills in eight weeks of history so the charts have something to show.

To try sync, run [cadence-api](https://github.com/sid-dutta/cadence-api) locally (`uvicorn app.main:app`) and sign in from Settings; the default server URL already points at `localhost:8000`.

## Design notes

The UI follows the conventions of Apple's own Health and Fitness apps rather than inventing its own: large titles, inset-grouped lists, system materials, SF Symbols, and a single accent color for actions. Strength and running data get one color each, used only for data. Numbers use the rounded system face with monospaced digits so they don't jitter as they update.

## Continuous integration

GitHub Actions runs `swift build`, `swift test`, and an `xcodebuild` of the app for the iOS Simulator on every push.

## License

MIT
