#if os(iOS) || os(macOS)
import Foundation

func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

enum PaywallCopy {
    enum CallToAction: Hashable {
        case startTrial
        case subscribe
        case purchase

        var title: String {
            switch self {
            case .startTrial: localized("paywall.startTrial")
            case .subscribe: localized("paywall.subscribe")
            case .purchase: localized("paywall.purchase")
            }
        }
    }

    static func displayName(_ plan: PaywallPlan) -> String {
        switch plan {
        case .monthly: localized("paywall.tier.monthly")
        case .yearly: localized("paywall.tier.yearly")
        case .lifetime: localized("paywall.tier.lifetime")
        }
    }

    static func hasEligibleIntroOffer(_ product: PaywallProduct?) -> Bool {
        guard let product else { return false }
        return product.isEligibleForIntroOffer && product.introductoryOfferText != nil
    }

    static func trialConversionDisclosure(for product: PaywallProduct?) -> String? {
        guard let product, self.hasEligibleIntroOffer(product),
              let trial = product.introductoryOfferText else { return nil }

        switch product.plan {
        case .monthly:
            return localized("paywall.cta.reassurance.trial.monthly \(trial) \(product.displayPrice)")
        case .yearly:
            return localized("paywall.cta.reassurance.trial.yearly \(trial) \(product.displayPrice)")
        case .lifetime:
            return nil
        }
    }

    static func subtitle(for plan: PaywallPlan, product: PaywallProduct?) -> String {
        if self.hasEligibleIntroOffer(product), let trial = product?.introductoryOfferText {
            return trial
        }

        switch plan {
        case .monthly: return localized("paywall.billing.monthly")
        case .yearly: return localized("paywall.billing.yearly")
        case .lifetime: return localized("paywall.billing.lifetime")
        }
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

    static func badge(for plan: PaywallPlan, products: [PaywallProduct]) -> String? {
        guard plan == .yearly,
              let monthly = products.first(where: { $0.plan == .monthly }),
              let yearly = products.first(where: { $0.plan == .yearly }),
              let percent = self.yearlySavingsPercent(monthlyPrice: monthly.price, yearlyPrice: yearly.price)
        else { return nil }
        return localized("paywall.badge.savePercent \(percent)")
    }

    static func callToAction(for plan: PaywallPlan, product: PaywallProduct?) -> CallToAction {
        switch plan {
        case .monthly, .yearly:
            self.hasEligibleIntroOffer(product) ? .startTrial : .subscribe
        case .lifetime:
            .purchase
        }
    }

    static func reassurance(for plan: PaywallPlan, product: PaywallProduct?) -> String {
        if let disclosure = self.trialConversionDisclosure(for: product) {
            return disclosure
        }

        switch plan {
        case .monthly, .yearly:
            return localized("paywall.cta.reassurance.subscription")
        case .lifetime:
            return localized("paywall.cta.reassurance.lifetime")
        }
    }

    static func accessibilityLabel(for plan: PaywallPlan, product: PaywallProduct?, badge: String?) -> String {
        var components = [self.displayName(plan)]

        if let disclosure = self.trialConversionDisclosure(for: product) {
            components.append(disclosure)
        } else if let price = product?.displayPrice {
            components.append(price)
        }

        if let badge {
            components.append(badge)
        }

        return components.joined(separator: ", ")
    }
}
#endif
