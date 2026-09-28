# Changelog

All notable changes to PaywallKit are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-09-28

### Fixed

- Builds with Xcode 26.6: the entitlement observation no longer crashes the Swift 6.3 compiler.

### Changed

- **Breaking for conformers that were not already Sendable:** `PaywallService` now refines `Sendable`. `@MainActor` classes and structs holding Sendable values already are.

## [1.0.0] - 2026-09-28

### Added

- `PaywallView`: Swiftflip's paywall as a package. It covers the icon hero, the benefits list with a highlighted row, monthly / yearly / lifetime plan cards with trial and savings copy, the morphing call to action, Terms / Privacy / Restore, and the in-sheet thank-you celebration.
- `PaywallService`: the app's store behind six members. The kit runs the purchase flow: loading, retry, selection, purchase, restore, Ask to Buy, alerts and the thanks timeline.
- English and Swedish copy.
