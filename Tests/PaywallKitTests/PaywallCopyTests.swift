#if os(iOS) || os(macOS)
import Foundation
import Testing
@testable import PaywallKit

struct PaywallCopyTests {
    private static let strings: @Sendable (PaywallString) -> String = { "\($0)" }

    private static func product(_ plan: PaywallPlan, price: Decimal = 0, trial: String? = nil) -> PaywallProduct {
        PaywallProduct(
            plan: plan,
            displayPrice: "$9.99",
            price: price,
            introductoryOfferText: trial,
            isEligibleForIntroOffer: trial != nil)
    }

    private static let priced: [PaywallProduct] = [
        product(.monthly, price: 10),
        product(.yearly, price: 100),
        product(.lifetime, price: 200),
    ]

    @Test
    func `monthly and yearly share a call to action unless a trial is offered`() {
        #expect(PaywallCopy.callToAction(for: .monthly, product: Self.product(.monthly)) == .subscribe)
        #expect(PaywallCopy.callToAction(for: .yearly, product: Self.product(.yearly)) == .subscribe)
        #expect(PaywallCopy.callToAction(for: .yearly, product: Self.product(.yearly, trial: "7 days free")) == .startTrial)
        #expect(PaywallCopy.callToAction(for: .lifetime, product: Self.product(.lifetime)) == .purchase)
    }

    @Test
    func `without an offer each plan shows its billing line`() {
        for plan in PaywallPlan.allCases {
            #expect(PaywallCopy.subtitle(for: plan, product: Self.product(plan), strings: Self.strings)
                == Self.strings(.billing(plan)))
        }
    }

    @Test
    func `an eligible intro offer replaces the billing subtitle`() {
        let offered = Self.product(.yearly, price: 100, trial: "7 days free")
        #expect(PaywallCopy.subtitle(for: .yearly, product: offered, strings: Self.strings) == "7 days free")
    }

    @Test
    func `an ineligible offer falls back to the billing subtitle`() {
        let ineligible = PaywallProduct(
            plan: .yearly,
            displayPrice: "$9.99",
            introductoryOfferText: "7 days free",
            isEligibleForIntroOffer: false)
        #expect(
            PaywallCopy.subtitle(for: .yearly, product: ineligible, strings: Self.strings)
                == Self.strings(.billing(.yearly)))
    }

    @Test
    func `an intro offer needs both display text and eligibility`() {
        #expect(PaywallCopy.hasEligibleIntroOffer(Self.product(.yearly, trial: "Free trial")))
        #expect(!PaywallCopy.hasEligibleIntroOffer(PaywallProduct(
            plan: .yearly, displayPrice: "$59.99", introductoryOfferText: "Free trial")))
        #expect(!PaywallCopy.hasEligibleIntroOffer(PaywallProduct(
            plan: .yearly, displayPrice: "$59.99", isEligibleForIntroOffer: true)))
        #expect(PaywallCopy.trialConversionDisclosure(for: PaywallProduct(
            plan: .yearly, displayPrice: "$39.99", isEligibleForIntroOffer: true)) == nil)
    }

    @Test
    func `trial disclosures name the conversion price and cadence`() {
        let monthly = PaywallProduct(
            plan: .monthly, displayPrice: "$5.99", introductoryOfferText: "1 month free", isEligibleForIntroOffer: true)
        let yearly = PaywallProduct(
            plan: .yearly, displayPrice: "$39.99", introductoryOfferText: "7 days free", isEligibleForIntroOffer: true)

        #expect(
            PaywallCopy.trialConversionDisclosure(for: monthly)
                == .monthlyTrialDisclosure(trial: "1 month free", price: "$5.99"))
        #expect(
            PaywallCopy.trialConversionDisclosure(for: yearly)
                == .yearlyTrialDisclosure(trial: "7 days free", price: "$39.99"))
    }

    @Test
    func `only the yearly plan carries a savings badge`() {
        #expect(PaywallCopy.badge(for: .yearly, products: Self.priced) == .savePercent(16))
        #expect(PaywallCopy.badge(for: .monthly, products: Self.priced) == nil)
        #expect(PaywallCopy.badge(for: .lifetime, products: Self.priced) == nil)
    }

    @Test
    func `the savings badge needs both prices`() {
        #expect(PaywallCopy.badge(for: .yearly, products: []) == nil)
        #expect(PaywallCopy.badge(for: .yearly, products: [Self.product(.yearly, price: 100)]) == nil)
    }

    @Test
    func `the savings badge disappears when the yearly plan saves nothing`() {
        let noSaving = [
            Self.product(.monthly, price: 10),
            Self.product(.yearly, price: 120),
        ]
        #expect(PaywallCopy.badge(for: .yearly, products: noSaving) == nil)
    }

    @Test(arguments: [
        (2.99, 29.99, Optional(16)),
        (4.99, 39.99, 33),
        (10, 81, 32),
        (1, 12, nil),
        (1, 13, nil),
        (0, 29.99, nil),
        (2.99, 0, nil),
        (10, 119.99, nil),
    ])
    func `calculates yearly savings`(monthlyPrice: Decimal, yearlyPrice: Decimal, expected: Int?) {
        #expect(PaywallCopy.yearlySavingsPercent(monthlyPrice: monthlyPrice, yearlyPrice: yearlyPrice) == expected)
    }

    @Test
    func `a trial disclosure replaces the reassurance line`() {
        let offered = Self.product(.yearly, price: 100, trial: "7 days free")
        #expect(PaywallCopy.reassurance(for: .yearly, product: offered)
            == .yearlyTrialDisclosure(trial: "7 days free", price: "$9.99"))
        #expect(PaywallCopy.reassurance(for: .yearly, product: nil) == .subscriptionReassurance)
    }

    @Test
    func `lifetime reassurance differs from the subscription reassurance`() {
        #expect(PaywallCopy.reassurance(for: .lifetime, product: nil) == .lifetimeReassurance)
    }

    @Test
    func `the accessibility label names the plan, price and badge`() {
        let label = PaywallCopy.accessibilityLabel(
            for: .yearly,
            product: Self.product(.yearly, price: 100),
            badge: .savePercent(17),
            strings: Self.strings)

        #expect(label == [Self.strings(.plan(.yearly)), "$9.99", Self.strings(.savePercent(17))].joined(separator: ", "))
    }

    @Test
    func `the accessibility label survives a missing product`() {
        let label = PaywallCopy.accessibilityLabel(for: .lifetime, product: nil, badge: nil, strings: Self.strings)
        #expect(label == Self.strings(.plan(.lifetime)))
    }

}
#endif
