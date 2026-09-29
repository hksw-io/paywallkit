#if os(iOS) || os(macOS)
import Foundation

/// The app's store and entitlement backend. `PaywallView` drives the whole purchase flow through it.
///
/// `entitlement` must be read from an `@Observable` type: the paywall observes it to celebrate an
/// approval that lands while it is open (Ask to Buy, another device) and to close itself when access
/// turns out to be active already.
@MainActor
public protocol PaywallService: Sendable {
    var entitlement: PaywallEntitlement { get }
    var products: [PaywallProduct] { get }
    var canMakePayments: Bool { get }

    func loadProducts(forceRefresh: Bool) async
    /// Throw a `PaywallError` for a specific alert; any other error shows the generic failure.
    func purchase(_ plan: PaywallPlan) async throws
    func restorePurchases() async throws
}

public enum PaywallEntitlement: Sendable, Equatable {
    case unknown
    case free
    case entitled
}

public enum PaywallPlan: String, CaseIterable, Sendable {
    case monthly
    case yearly
    case lifetime
}

public struct PaywallProduct: Identifiable, Equatable, Sendable {
    public var plan: PaywallPlan
    public var displayPrice: String
    public var price: Decimal
    public var monthlyEquivalentPrice: String?
    /// Short free-trial copy such as "7 days free", shown when the user is eligible.
    public var introductoryOfferText: String?
    public var isEligibleForIntroOffer: Bool

    public var id: PaywallPlan {
        self.plan
    }

    public init(
        plan: PaywallPlan,
        displayPrice: String,
        price: Decimal = 0,
        monthlyEquivalentPrice: String? = nil,
        introductoryOfferText: String? = nil,
        isEligibleForIntroOffer: Bool = false)
    {
        self.plan = plan
        self.displayPrice = displayPrice
        self.price = price
        self.monthlyEquivalentPrice = monthlyEquivalentPrice
        self.introductoryOfferText = introductoryOfferText
        self.isEligibleForIntroOffer = isEligibleForIntroOffer
    }
}

public enum PaywallError: Error, Sendable, Equatable {
    case cancelled
    case pending
    case paymentsNotAllowed
    case productNotFound
    case verificationFailed
    /// The purchase went through but did not grant access.
    case notActivated
    case failed
}

/// Every piece of copy the paywall shows or speaks. The kit ships no strings: pass `PaywallView` a
/// lookup that returns the app's localized text for each case.
public enum PaywallString: Hashable, Sendable {
    /// Heading above the benefits, such as "Everything in Premium".
    case benefitsHeader
    /// Appended to the highlighted benefit for VoiceOver, such as "the feature you tried to use".
    case highlightedBenefit
    /// A plan's name, such as "Monthly".
    case plan(PaywallPlan)
    /// A plan's billing line when no trial is offered, such as "Billed monthly" or "One-time purchase".
    case billing(PaywallPlan)
    /// The yearly plan's savings badge, such as "Save 20%".
    case savePercent(Int)
    /// The yearly plan's monthly equivalent, such as "$3.33/mo".
    case perMonth(price: String)
    case subscribe
    case startTrial
    case purchase
    /// Under the call to action for a subscription, such as "Cancel anytime."
    case subscriptionReassurance
    /// Under the call to action for the lifetime plan, such as "Yours forever after one purchase."
    case lifetimeReassurance
    /// The App Store's required trial-conversion disclosure for the monthly plan.
    case monthlyTrialDisclosure(trial: String, price: String)
    /// The App Store's required trial-conversion disclosure for the yearly plan.
    case yearlyTrialDisclosure(trial: String, price: String)
    /// Shown while a purchase runs, such as "Contacting the App Store…".
    case purchasing
    /// VoiceOver label for the call to action's success checkmark.
    case complete
    case termsOfUse
    case privacyPolicy
    case restore
    /// VoiceOver hint for Restore Purchases.
    case restoreHint
    /// The macOS dismiss button.
    case notNow
    /// VoiceOver label for the iOS close button.
    case close
    /// VoiceOver label for the plan placeholders while plans load.
    case loadingPlans
    case plansUnavailableTitle
    case plansUnavailableMessage
    case tryAgain
    case paymentsUnavailableTitle
    case paymentsUnavailableMessage
    case purchaseFailedTitle
    case purchaseFailed
    case pendingTitle
    case pending
    case productNotFound
    case verificationFailed
    /// The purchase went through but did not grant access.
    case notActivated
    case nothingToRestoreTitle
    case nothingToRestore
    case restoreFailedTitle
    case restoreFailed
    case ok
    case thanksTitle
    case restoredTitle
    case restoredSubtitle
}

public struct PaywallBenefit: Identifiable, Equatable, Sendable {
    public let id: String
    public let systemImage: String
    public let title: String

    public init(id: String, systemImage: String, title: String) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
    }
}
#endif
