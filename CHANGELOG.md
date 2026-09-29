# Changelog

All notable changes to PaywallKit are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.1] - 2026-09-29

### Fixed

- The paywall no longer freezes the app when its measured height changes by floating-point noise. On iPhone 17 Pro Max, opening it with a highlighted benefit re-measured the sheet forever at 100% CPU; changes under one point are now ignored.

## [1.1.0] - 2026-09-29

### Changed

- **Breaking:** `PaywallView` requires `strings:`, a lookup that returns the app's text for each `PaywallString` case. Apps name their own subscription instead of "Premium" and localize the paywall in their own catalog. The README carries the previous English copy as a starting point. This ships as a minor release by choice; an app resolving "Up to Next Major" from 1.0.x must pass `strings:` when it updates.

### Removed

- The bundled English and Swedish string catalog. The kit contains no copy.

## [1.0.1] - 2026-09-28

### Fixed

- Builds with Xcode 26.6: the entitlement observation no longer crashes the Swift 6.3 compiler.

### Changed

- `PaywallService` refines `Sendable`. `@MainActor` classes and structs holding Sendable values already conform; 1.0.0 was public for under an hour with no outside conformers, so this ships as a patch.

## [1.0.0] - 2026-09-28

### Added

- `PaywallView`: Swiftflip's paywall as a package. It covers the icon hero, the benefits list with a highlighted row, monthly / yearly / lifetime plan cards with trial and savings copy, the morphing call to action, Terms / Privacy / Restore, and the in-sheet thank-you celebration.
- `PaywallService`: the app's store behind six members. The kit runs the purchase flow: loading, retry, selection, purchase, restore, Ask to Buy, alerts and the thanks timeline.
- English and Swedish copy.
