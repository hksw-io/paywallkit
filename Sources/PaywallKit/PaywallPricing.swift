#if os(iOS) || os(macOS)
import SwiftUI

struct PaywallPricing: View {
    let model: PaywallModel

    @Environment(\.paywallHapticsEnabled) private var hapticEnabled
    @Environment(\.paywallStrings) private var strings

    var body: some View {
        Group {
            if self.model.isLoadingProducts {
                PaywallPricingSkeleton()
            } else if self.model.paymentsUnavailable {
                PaywallPricingMessage(
                    title: self.strings(.paymentsUnavailableTitle),
                    message: self.strings(.paymentsUnavailableMessage),
                    onRetry: nil)
            } else if self.model.productsUnavailable {
                PaywallPricingMessage(
                    title: self.strings(.plansUnavailableTitle),
                    message: self.strings(.plansUnavailableMessage),
                    onRetry: { Task { await self.model.retryLoadProducts() } })
            } else {
                VStack(spacing: 6) {
                    ForEach(self.model.products) { product in
                        PaywallTierButton(model: self.model, tier: product.id)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: self.model.selectedPlan) { _, _ in self.hapticEnabled }
    }
}

private struct PaywallTierButton: View {
    let model: PaywallModel
    let tier: PaywallPlan

    @Environment(\.paywallStrings) private var strings

    var body: some View {
        Button {
            self.model.select(self.tier)
        } label: {
            PaywallTierCard(model: self.model, tier: self.tier)
        }
        .buttonStyle(.plain)
        .disabled(self.model.isPurchasing)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(self.model.selectedPlan == self.tier ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(
            PaywallCopy.accessibilityLabel(
                for: self.tier,
                product: self.model.product(for: self.tier),
                badge: PaywallCopy.badge(for: self.tier, products: self.model.products),
                strings: self.strings.lookup))
    }
}

private struct PaywallTierRadio: View {
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(self.isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                .frame(width: PaywallMetrics.radioOuterSize, height: PaywallMetrics.radioOuterSize)

            if self.isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: PaywallMetrics.radioInnerSize, height: PaywallMetrics.radioInnerSize)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(self.reduceMotion ? nil : Tokens.Animations.selectionPop, value: self.isSelected)
    }
}

private struct PaywallSavingsBadge: View {
    let text: String

    var body: some View {
        Text(self.text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor, in: .capsule)
    }
}

private struct PaywallTierCard: View {
    let model: PaywallModel
    let tier: PaywallPlan

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.paywallSheetHeight) private var sheetHeight
    @Environment(\.paywallStrings) private var strings

    private var isSelected: Bool {
        self.model.selectedPlan == self.tier
    }

    private var product: PaywallProduct? {
        self.model.product(for: self.tier)
    }

    var body: some View {
        self.layout
            .padding(.horizontal, 16)
            .padding(.vertical, PaywallMetrics.tierVerticalPadding(for: self.sheetHeight))
            .background {
                RoundedRectangle(cornerRadius: PaywallMetrics.tierCornerRadius, style: .continuous)
                    .fill(Tokens.Colors.elevatedCardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: PaywallMetrics.tierCornerRadius, style: .continuous)
                            .stroke(
                                self.isSelected
                                    ? Color.accentColor.opacity(0.9)
                                    : Tokens.Colors.separator,
                                lineWidth: self.isSelected ? 2 : 1)
                    }
                    .shadow(
                        color: Tokens.Colors.subtleShadow.opacity(self.isSelected ? 1 : 0.6),
                        radius: self.isSelected ? 14 : 6,
                        x: 0,
                        y: self.isSelected ? 6 : 3)
            }
            .animation(self.reduceMotion ? nil : Tokens.Animations.felt, value: self.isSelected)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var layout: some View {
        if self.dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: 14) {
                PaywallTierRadio(isSelected: self.isSelected)

                VStack(alignment: .leading, spacing: 6) {
                    self.name

                    if let badge = PaywallCopy.badge(for: self.tier, products: self.model.products) {
                        PaywallSavingsBadge(text: self.strings(badge))
                    }

                    self.subtitle

                    self.priceBlock(alignment: .leading)
                }

                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 14) {
                PaywallTierRadio(isSelected: self.isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        self.name
                            .layoutPriority(1)

                        if let badge = PaywallCopy.badge(for: self.tier, products: self.model.products) {
                            PaywallSavingsBadge(text: self.strings(badge))
                        }
                    }

                    self.subtitle
                }

                Spacer()

                self.priceBlock(alignment: .trailing)
            }
        }
    }

    private var name: some View {
        Text(self.strings(.plan(self.tier)))
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(self.dynamicTypeSize.isAccessibilitySize ? 2 : 1)
    }

    private var subtitle: some View {
        Text(PaywallCopy.subtitle(for: self.tier, product: self.product, strings: self.strings.lookup))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(self.dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func priceBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(self.product?.displayPrice ?? "—")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let monthlyEquivalent = self.product?.monthlyEquivalentPrice {
                Text(self.strings(.perMonth(price: monthlyEquivalent)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(self.dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
        }
    }
}

private struct PaywallPricingMessage: View {
    let title: String
    let message: String
    let onRetry: (() -> Void)?

    @Environment(\.paywallStrings) private var strings

    var body: some View {
        VStack(spacing: 12) {
            Text(self.title)
                .font(.headline)

            Text(self.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let onRetry {
                Button(self.strings(.tryAgain), action: onRetry)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
#endif
