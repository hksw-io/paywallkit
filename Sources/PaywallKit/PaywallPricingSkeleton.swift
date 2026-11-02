#if os(iOS) || os(macOS)
import SwiftUI

struct PaywallPricingSkeleton: View {
    let planCount: Int

    @State private var shimmerPhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.paywallAnimatesDecorations) private var decorativeMotionEnabled
    @Environment(\.paywallSheetHeight) private var sheetHeight
    @Environment(\.paywallStrings) private var strings

    var body: some View {
        self.placeholders
            .overlay {
                if !self.reduceMotion, self.decorativeMotionEnabled {
                    self.shimmerSweep
                }
            }
            .accessibilityElement()
            .accessibilityLabel(self.strings(.loadingPlans))
            .onAppear {
                guard !self.reduceMotion, self.decorativeMotionEnabled else { return }
                withAnimation(Tokens.Animations.skeletonShimmer) {
                    self.shimmerPhase = 1
                }
            }
    }

    private var placeholders: some View {
        VStack(spacing: 6) {
            ForEach(0 ..< self.planCount, id: \.self) { _ in
                self.cardPlaceholder
            }
        }
    }

    private var cardPlaceholder: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Tokens.Colors.subtleFill.opacity(0.35))
                .frame(width: PaywallMetrics.radioOuterSize, height: PaywallMetrics.radioOuterSize)

            VStack(alignment: .leading, spacing: 2) {
                self.bar(font: .headline.weight(.semibold), width: 120, opacity: 0.35)
                self.bar(font: .subheadline, width: 80, opacity: 0.25)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                self.bar(font: .title3.weight(.bold), width: 56, opacity: 0.35)
                Text(verbatim: " ")
                    .font(.caption)
                    .hidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, PaywallMetrics.tierVerticalPadding(for: self.sheetHeight))
        .background {
            RoundedRectangle(cornerRadius: PaywallMetrics.tierCornerRadius, style: .continuous)
                .fill(Tokens.Colors.elevatedCardBackground)
        }
    }

    /// A line as tall as the text it stands in for, so a row measures like its tier card at any
    /// text size.
    private func bar(font: Font, width: CGFloat, opacity: Double) -> some View {
        Text(verbatim: " ")
            .font(font)
            .hidden()
            .frame(width: width)
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Tokens.Colors.subtleFill.opacity(opacity))
                    .padding(.vertical, 1)
            }
    }

    private var shimmerSweep: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.35), .clear],
                startPoint: .leading,
                endPoint: .trailing)
                .frame(width: width * 0.4)
                .offset(x: -width * 0.4 + self.shimmerPhase * width * 1.4)
        }
        .mask(self.placeholders)
        .allowsHitTesting(false)
    }
}
#endif
