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
        strings: paywallText,
        onDismiss: { showsPaywall = false })
}
```

`highlightedBenefitID` names the feature the user just tried to use; that row is tinted and
announced. Set `brand` and `brandLight` to your brand colours (both default to the accent colour),
pass `wallpaperSymbols` for a faint tiled backdrop, and forward your app's haptics preference as
`hapticsEnabled`. `animatesDecorations: false` stills the ambient loops, for example under UI tests.

`onDismiss` runs for both a cancel and a completed purchase. Read your own entitlement afterwards to
tell them apart.

### The copy

The kit ships no strings. `strings` returns your app's text for every `PaywallString`, so the
paywall names your subscription and localizes with the rest of your app. An exhaustive `switch`
makes the compiler flag any case you miss. This English copy is a starting point:

```swift
import PaywallKit

@Sendable
func paywallText(_ string: PaywallString) -> String {
    switch string {
    case .benefitsHeader: String(localized: "Everything in Premium")
    case .highlightedBenefit: String(localized: "the feature you tried to use")
    case .plan(.monthly): String(localized: "Monthly")
    case .plan(.yearly): String(localized: "Yearly")
    case .plan(.lifetime): String(localized: "Lifetime")
    case .billing(.monthly): String(localized: "Billed monthly")
    case .billing(.yearly): String(localized: "Billed yearly")
    case .billing(.lifetime): String(localized: "One-time purchase")
    case let .savePercent(percent): String(localized: "Save \(percent)%")
    case let .perMonth(price): String(localized: "\(price)/mo")
    case .subscribe: String(localized: "Subscribe")
    case .startTrial: String(localized: "Start Free Trial")
    case .purchase: String(localized: "Purchase")
    case .subscriptionReassurance: String(localized: "Cancel anytime.")
    case .lifetimeReassurance: String(localized: "Yours forever after one purchase.")
    case let .monthlyTrialDisclosure(trial, price):
        String(localized: "\(trial), then \(price) is charged automatically each month until canceled.")
    case let .yearlyTrialDisclosure(trial, price):
        String(localized: "\(trial), then \(price) is charged automatically each year until canceled.")
    case .purchasing: String(localized: "Contacting the App Store…")
    case .complete: String(localized: "Complete")
    case .termsOfUse: String(localized: "Terms of Use")
    case .privacyPolicy: String(localized: "Privacy Policy")
    case .restore: String(localized: "Restore Purchases")
    case .restoreHint: String(localized: "Restore a previous purchase on this Apple Account")
    case .notNow: String(localized: "Not Now")
    case .close: String(localized: "Close")
    case .loadingPlans: String(localized: "Loading plans")
    case .plansUnavailableTitle: String(localized: "Couldn’t Load Plans")
    case .plansUnavailableMessage: String(localized: "Check your connection and try again.")
    case .tryAgain: String(localized: "Try Again")
    case .paymentsUnavailableTitle: String(localized: "Purchases Not Available")
    case .paymentsUnavailableMessage: String(localized: "In-app purchases are turned off for this device or account.")
    case .purchaseFailedTitle: String(localized: "Couldn’t Complete Purchase")
    case .purchaseFailed: String(localized: "The purchase didn’t go through. Try again.")
    case .pendingTitle: String(localized: "Purchase Pending")
    case .pending: String(localized: "Your purchase is awaiting approval. You’ll get access as soon as it’s approved.")
    case .productNotFound: String(localized: "This plan isn’t available right now. Try again later.")
    case .verificationFailed: String(localized: "Your purchase couldn’t be verified. Try again.")
    case .notActivated: String(localized: "This purchase didn’t activate Premium. Try again, or choose Restore Purchases.")
    case .nothingToRestoreTitle: String(localized: "Nothing to Restore")
    case .nothingToRestore: String(localized: "There are no purchases to restore on this account.")
    case .restoreFailedTitle: String(localized: "Couldn’t Restore Purchases")
    case .restoreFailed: String(localized: "Purchases couldn’t be restored. Try again.")
    case .ok: String(localized: "OK")
    case .thanksTitle: String(localized: "Welcome to Premium")
    case .restoredTitle: String(localized: "Purchases Restored")
    case .restoredSubtitle: String(localized: "Your Premium is back.")
    }
}
```

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
- The kit ships no copy; the app supplies every string through `PaywallString`.
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

## License

MIT. See [LICENSE](LICENSE).
