# PaywallKit

[![CI](https://github.com/hksw-io/paywallkit/actions/workflows/ci.yml/badge.svg)](https://github.com/hksw-io/paywallkit/actions/workflows/ci.yml)

A reusable SwiftUI paywall for iOS and macOS apps in the HK Softworks portfolio: the app icon with
a brand glow, the benefits list, monthly / yearly / lifetime plan cards, a call-to-action that morphs
through purchase, and an in-sheet thank-you celebration.

The kit owns the purchase flow — loading plans, selection, purchase, restore, Ask to Buy, alerts
and the celebration. The app owns StoreKit and entitlement policy behind a small `PaywallService`
protocol. No dependencies.

## Requirements

- iOS 26+ / macOS 26+
- Swift 6.2+

## Installation

```swift
.package(url: "https://github.com/hksw-io/paywallkit.git", from: "1.0.0")
```

Or in Xcode: **File > Add Package Dependencies**, enter the URL above, and choose **Up to Next Major Version** from `1.0.0`.

## Usage

Present `PaywallView` in a sheet:

```swift
import PaywallKit
import SwiftUI

.sheet(isPresented: $showsPaywall) {
    PaywallView(
        service: store,
        icon: Image("AppIconImage"),
        benefits: [
            PaywallBenefit(id: "sync", systemImage: "icloud", title: String(localized: "Sync across devices")),
            PaywallBenefit(id: "themes", systemImage: "paintpalette", title: String(localized: "Custom themes")),
        ],
        highlightedBenefitID: "themes",
        thanksLines: [Text("Thank you for supporting MyApp.")],
        privacyPolicy: URL(string: "https://example.com/privacy")!,
        onDismiss: { showsPaywall = false })
}
```

`highlightedBenefitID` names the feature the user just tried to use; that row is tinted and
announced. Set `brand` and `brandLight` to your brand colours (both default to the accent colour),
pass `wallpaperSymbols` for a faint tiled backdrop, and forward your app's haptics preference as
`hapticsEnabled`. `animatesDecorations: false` stills the ambient loops, for example under UI tests.

`onDismiss` runs for both a cancel and a completed purchase. Read your own entitlement afterwards to
tell them apart.

### The service

Conform your store to `PaywallService`. `entitlement` must live on an `@Observable` type: the
paywall watches it to celebrate an approval that arrives while it is open and to close itself when
access is already active. A minimal StoreKit 2 conformance:

```swift
import PaywallKit
import StoreKit

@MainActor
@Observable
final class Store: PaywallService {
    private(set) var entitlement: PaywallEntitlement = .unknown
    private(set) var products: [PaywallProduct] = []
    private var storeProducts: [PaywallPlan: Product] = [:]
    private let productIDs: [PaywallPlan: String] = [
        .monthly: "com.example.premium.monthly",
        .yearly: "com.example.premium.yearly",
    ]

    var canMakePayments: Bool {
        AppStore.canMakePayments
    }

    func loadProducts(forceRefresh: Bool) async {
        guard forceRefresh || self.products.isEmpty else { return }
        do {
            let loaded = try await Product.products(for: Array(self.productIDs.values))
            for (plan, id) in self.productIDs {
                self.storeProducts[plan] = loaded.first { $0.id == id }
            }
            self.products = self.storeProducts.map { plan, product in
                PaywallProduct(plan: plan, displayPrice: product.displayPrice, price: product.price)
            }
        } catch {
            self.products = []
        }
    }

    func purchase(_ plan: PaywallPlan) async throws {
        guard let product = self.storeProducts[plan] else { throw PaywallError.productNotFound }
        switch try await product.purchase() {
        case let .success(.verified(transaction)):
            await transaction.finish()
            await self.refreshEntitlement()
            guard self.entitlement == .entitled else { throw PaywallError.notActivated }
        case .success(.unverified):
            throw PaywallError.verificationFailed
        case .pending:
            throw PaywallError.pending
        case .userCancelled:
            throw PaywallError.cancelled
        @unknown default:
            throw PaywallError.failed
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await self.refreshEntitlement()
    }

    func refreshEntitlement() async {
        var isEntitled = false
        for await case let .verified(transaction) in Transaction.currentEntitlements
            where transaction.revocationDate == nil
        {
            isEntitled = isEntitled || self.productIDs.values.contains(transaction.productID)
        }
        self.entitlement = isEntitled ? .entitled : .free
    }
}
```

A real app also calls `refreshEntitlement()` at launch and listens to `Transaction.updates`.
Fill `introductoryOfferText` ("7 days free") and `isEligibleForIntroOffer` from
`product.subscription` to get the trial call to action and the App Store's required
trial-conversion disclosure, and `monthlyEquivalentPrice` to show the yearly plan per month. The
yearly plan's savings badge is computed from `price`.

Throw `PaywallError` for a specific alert. `.cancelled`, `CancellationError` and
`StoreKitError.userCancelled` are silent; any other error shows the generic failure.

## Scope

- Plans are monthly, yearly and lifetime; any subset renders.
- Copy ships in English and Swedish and says "Premium".
- Terms of Use link Apple's standard EULA.

## Accessibility

VoiceOver reads each plan as one element with its price, trial disclosure and savings, and marks
the selection with a trait. The thank-you title is announced. Accessibility text sizes switch to a
scrolling layout. Reduce Motion removes decorative motion, turns the celebration into a crossfade
and keeps every haptic.

## Local development

```sh
swift test
```

`swift test` builds for macOS only. Build iOS too when touching platform-conditional code:

```sh
xcodebuild -scheme PaywallKit -destination 'generic/platform=iOS Simulator' build
```

Toolchains before Swift 6.4 do not compile the string catalog under `swift test`, so tests compare
against the kit's own lookups, never English literals.

## License

MIT. See [LICENSE](LICENSE).
