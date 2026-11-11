# Changelog

All notable changes to PaywallKit are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `benefitsHeader` and `benefitsSubtitle` on `PaywallView`: optional text for one presentation that replaces `.benefitsHeader` and `.benefitsSubtitle` from `strings`. Both default to `nil`, so existing call sites compile unchanged, and apps no longer need to wrap `strings` to vary the heading.
- On Mac the purchase button is the sheet's default button, so Return presses it.

### Changed

- A plan with an eligible intro offer shows `introductoryOfferText` as an outlined badge beside its name and keeps its billing line underneath; before, the trial text replaced the billing line. On a card too narrow for the savings and trial badges together, the trial badge drops under the name. VoiceOver reads a plan as its name, price, billing line, savings and trial; the trial disclosure stays in the caption under the purchase button. A lifetime product never shows a trial badge.
- The paywall reads `products` and `canMakePayments` from the service on every update instead of copying them when `loadProducts` returns. Plans the service already holds are on screen in the first frame with the purchase button enabled, and a later change to `products` updates the open paywall. The loading placeholder shows only while the service has no plans and the first load has not returned. Keep both properties on the `@Observable` type.
- The sheet cannot be swiped away while a purchase runs. Apps no longer need their own `interactiveDismissDisabled` for that.

### Fixed

- The caption under the purchase button was cut off after two lines, which could truncate the trial disclosure in longer translations. It still reserves two lines and now grows past them.
- At accessibility text sizes the purchase button scrolled with the content and started below the fold. It now stays pinned at the bottom; its caption and the footer links scroll.
- Try Again gave no sign that plans were reloading. It now shows the loading placeholder until the load returns, and further taps are ignored meanwhile.
- The yearly savings badge could show one percent too little: monthly 10 and yearly 85.20 showed 28% for an exact 29%. The percentage is now rounded down in `Decimal`.
- The backdrop glow ignored `brand` and `brandLight` and was always the accent colour and blue. It now uses the brand colours, which default to the accent colour.

## [1.3.0] - 2026-11-02

### Added

- `loadingPlanCount` on `PaywallView`: how many plans the app sells. It defaults to 3, so apps that sell fewer should pass their count.

### Fixed

- The sheet changed height when the plans finished loading or failed to load. The placeholder now measures like the plans, and what replaces it keeps its height.

## [1.2.0] - 2026-10-06

### Added

- `PaywallString.benefitsSubtitle`: a sentence under the heading, hidden when the app returns an empty string. Apps that switch over `PaywallString` need a case for it.

### Fixed

- On Mac the purchase button's label stayed white when its window was in the background, where macOS draws the button grey. The label now follows the system colour there.

## [1.1.3] - 2026-09-30

### Fixed

- While Restore Purchases runs, the purchase button keeps its normal look instead of dimming behind the App Store's sign-in sheet. It ignores taps until the restore finishes.

## [1.1.2] - 2026-09-29

### Fixed

- On iPad the paywall sheet fits its content, so the Lifetime plan is no longer hidden behind the purchase button.
- When the paywall has to scroll, for example when it opens over another sheet, it starts scrolled to the plans so every plan is visible above the purchase button.

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
