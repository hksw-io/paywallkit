#if os(iOS) || os(macOS)
import SwiftUI

struct PaywallBenefitsSection: View {
    let benefits: [PaywallBenefit]
    let highlightedID: String?

    @Environment(\.paywallSheetHeight) private var sheetHeight
    @Environment(\.paywallStrings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
            Text(self.strings(.benefitsHeader))
                .font(PaywallMetrics.titleFont(for: self.sheetHeight))
                .foregroundStyle(PaywallTitleStyle.gradient)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            PaywallBenefitsList(benefits: self.benefits, highlightedID: self.highlightedID)
        }
        .background {
            self.softScrim
        }
    }

    private var softScrim: some View {
        RoundedRectangle(cornerRadius: Tokens.Radius.xLarge, style: .continuous)
            .fill(Tokens.Colors.background)
            .opacity(0.72)
            .blur(radius: 40)
            .padding(-34)
            .allowsHitTesting(false)
    }
}

struct PaywallBenefitsList: View {
    let benefits: [PaywallBenefit]
    let highlightedID: String?

    @Environment(\.paywallSheetHeight) private var sheetHeight

    var body: some View {
        VStack(alignment: .leading, spacing: PaywallMetrics.benefitRowSpacing(for: self.sheetHeight)) {
            ForEach(self.benefits) { benefit in
                PaywallBenefitRow(benefit: benefit, isFocused: benefit.id == self.highlightedID)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PaywallBenefitRow: View {
    let benefit: PaywallBenefit
    let isFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.paywallSheetHeight) private var sheetHeight
    @Environment(\.paywallBrand) private var brand
    @Environment(\.paywallStrings) private var strings
    @State private var haloAngle: Double = 0

    private var tileSize: CGFloat {
        PaywallMetrics.benefitTileSize(for: self.sheetHeight)
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.medium) {
            Image(systemName: self.benefit.systemImage)
                .font(.system(size: self.tileSize * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: self.tileSize, height: self.tileSize)
                .background(
                    self.brand.gradient,
                    in: .rect(cornerRadius: self.tileSize * 0.23, style: .continuous))
                .accessibilityHidden(true)

            Text(self.benefit.title)
                .font(PaywallMetrics.benefitFont(for: self.sheetHeight))
                .fontWeight(self.isFocused ? .semibold : .regular)
                .foregroundStyle(.primary)
                .lineLimit(self.dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Spacing.medium)
        .padding(.vertical, PaywallMetrics.benefitRowVerticalPadding(for: self.sheetHeight))
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                .fill(Color.accentColor.opacity(self.isFocused ? 0.1 : 0))
        }
        .overlay {
            if self.isFocused {
                self.focusHalo
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.accessibilityLabel)
    }

    private var focusHalo: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)

        return shape
            .strokeBorder(Color.accentColor.opacity(0.14), lineWidth: 1)
            .overlay {
                GeometryReader { geometry in
                    let span = (
                        geometry.size.width * geometry.size.width
                            + geometry.size.height * geometry.size.height).squareRoot()
                    AngularGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.accentColor.opacity(0.3), location: 0.06),
                            .init(color: self.brand.light.opacity(0.45), location: 0.13),
                            .init(color: Color.accentColor.opacity(0.3), location: 0.2),
                            .init(color: .clear, location: 0.3),
                            .init(color: .clear, location: 1),
                        ],
                        center: .center)
                        .frame(width: span, height: span)
                        .rotationEffect(.degrees(self.haloAngle))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .mask {
                    shape
                        .strokeBorder(Color.white, lineWidth: 1.1)
                        .blur(radius: 1.1)
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                guard !self.reduceMotion else { return }
                withAnimation(Tokens.Animations.focusHalo) {
                    self.haloAngle = 360
                }
            }
    }

    private var accessibilityLabel: String {
        guard self.isFocused else { return self.benefit.title }
        return "\(self.benefit.title), \(self.strings(.highlightedBenefit))"
    }
}
#endif
