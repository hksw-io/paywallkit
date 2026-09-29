#if os(iOS) || os(macOS)
import Foundation

enum PaywallCopy {
    static func hasEligibleIntroOffer(_ product: PaywallProduct?) -> Bool {
        guard let product else { return false }
        return product.isEligibleForIntroOffer && product.introductoryOfferText != nil
    }

    static func trialConversionDisclosure(for product: PaywallProduct?) -> PaywallString? {
        guard let product, self.hasEligibleIntroOffer(product),
              let trial = product.introductoryOfferText else { return nil }

        switch product.plan {
        case .monthly:
            return .monthlyTrialDisclosure(trial: trial, price: product.displayPrice)
        case .yearly:
            return .yearlyTrialDisclosure(trial: trial, price: product.displayPrice)
        case .lifetime:
            return nil
        }
    }

    static func subtitle(
        for plan: PaywallPlan,
        product: PaywallProduct?,
        strings: (PaywallString) -> String) -> String
    {
        if self.hasEligibleIntroOffer(product), let trial = product?.introductoryOfferText {
            return trial
        }
        return strings(.billing(plan))
    }

    static func yearlySavingsPercent(monthlyPrice: Decimal, yearlyPrice: Decimal) -> Int? {
        guard monthlyPrice > 0, yearlyPrice > 0 else { return nil }
        let yearOfMonthly = monthlyPrice * 12
        guard yearOfMonthly > yearlyPrice else { return nil }
        let fraction = (yearOfMonthly - yearlyPrice) / yearOfMonthly
        let percent = Int((NSDecimalNumber(decimal: fraction).doubleValue * 100).rounded(.down))
        guard percent >= 1 else { return nil }
        return percent
    }

    static func badge(for plan: PaywallPlan, products: [PaywallProduct]) -> PaywallString? {
        guard plan == .yearly,
              let monthly = products.first(where: { $0.plan == .monthly }),
              let yearly = products.first(where: { $0.plan == .yearly }),
              let percent = self.yearlySavingsPercent(monthlyPrice: monthly.price, yearlyPrice: yearly.price)
        else { return nil }
        return .savePercent(percent)
    }

    static func callToAction(for plan: PaywallPlan, product: PaywallProduct?) -> PaywallString {
        switch plan {
        case .monthly, .yearly:
            self.hasEligibleIntroOffer(product) ? .startTrial : .subscribe
        case .lifetime:
            .purchase
        }
    }

    static func reassurance(for plan: PaywallPlan, product: PaywallProduct?) -> PaywallString {
        if let disclosure = self.trialConversionDisclosure(for: product) {
            return disclosure
        }

        switch plan {
        case .monthly, .yearly:
            return .subscriptionReassurance
        case .lifetime:
            return .lifetimeReassurance
        }
    }

    static func accessibilityLabel(
        for plan: PaywallPlan,
        product: PaywallProduct?,
        badge: PaywallString?,
        strings: (PaywallString) -> String) -> String
    {
        var components = [strings(.plan(plan))]

        if let disclosure = self.trialConversionDisclosure(for: product) {
            components.append(strings(disclosure))
        } else if let price = product?.displayPrice {
            components.append(price)
        }

        if let badge {
            components.append(strings(badge))
        }

        return components.joined(separator: ", ")
    }
}
#endif
