# AGENTS.md

Instructions for agents working in this repository. RFC 2119 keywords apply.

## Package Scope

- This is a Swift package for a reusable SwiftUI paywall. The supported product surfaces are iOS 26+ and macOS 26+.
- watchOS is out of scope unless the user explicitly asks for it. Every source file MUST stay wrapped in `#if os(iOS) || os(macOS)`: consumers link the package into frameworks that also build for watchOS.
- The kit owns the purchase flow (`PaywallModel`). The consuming app owns StoreKit, entitlement policy and persistence behind `PaywallService`. Do not move app policy into the kit unless the public API is explicitly changed.

## SwiftUI Standards

- Use pure SwiftUI. Do not use deprecated APIs such as `foregroundColor`, old `alert` overloads, or `animation(_:)` without `value:`.
- Preserve accessibility in every UI change: VoiceOver labels and grouping, Dynamic Type (accessibility sizes switch to the scrolling layout), Reduce Motion, contrast, and light and dark mode.
- Reduce Motion removes decorative motion, turns causal motion into an instant crossfade, and keeps every haptic. `animatesDecorations` gates only the ambient loops.
- Keep `.accessibilityIdentifier("paywall.sheet")`. Consumers' UI tests find the sheet by it.
- Keep public API names, defaults, and initializer behavior stable unless the requested change explicitly requires a breaking change.

## Localization

- All copy lives in `Sources/PaywallKit/Resources/Localizable.xcstrings` (en, sv) and MUST be looked up through `localized(_:)`, which uses `bundle: .module`. A bare `Text("key")` or `LocalizedStringKey` resolves against the app's bundle and shows the raw key.
- Every entry keeps `extractionState: manual`.

## Testing and Verification

- Add or update Swift Testing coverage for every behavior change. `PaywallModelTests` drives the model with an `@Observable` fake service and a recorded `sleep`.
- Tests MUST compare copy through `localized(_:)`, never English literals: toolchains before Swift 6.4 do not compile the catalog under `swift test`.
- Run `swift test` and `xcodebuild -scheme PaywallKit -destination 'generic/platform=iOS Simulator' build` before calling work complete, and `git diff --check` before committing.
- CI (`.github/workflows/ci.yml`) runs macOS and iOS Simulator tests on Xcode 26.6 and 27.0. Keep it green.

## Documentation and Releases

- Keep README examples compiling against the public API.
- Record every public API or behavior change under `## [Unreleased]` in `CHANGELOG.md`.
- Releases are annotated SemVer tags without a `v` prefix (`1.0.1`). Never move a published tag.
- Use semantic commit messages: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`, `ci:`.
