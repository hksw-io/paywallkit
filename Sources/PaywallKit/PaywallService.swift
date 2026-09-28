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
