#if os(iOS) || os(macOS)
import SwiftUI

struct PaywallPricingSkeleton: View {
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
            ForEach(0 ..< 3, id: \.self) { _ in
                self.cardPlaceholder
            }
        }
    }

    private var cardPlaceholder: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Tokens.Colors.subtleFill.opacity(0.35))
                .frame(width: PaywallMetrics.radioOuterSize, height: PaywallMetrics.radioOuterSize)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Tokens.Colors.subtleFill.opacity(0.35))
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Tokens.Colors.subtleFill.opacity(0.25))
                    .frame(width: 80, height: 11)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Tokens.Colors.subtleFill.opacity(0.35))
                .frame(width: 56, height: 18)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, PaywallMetrics.tierVerticalPadding(for: self.sheetHeight))
        .background {
            RoundedRectangle(cornerRadius: PaywallMetrics.tierCornerRadius, style: .continuous)
                .fill(Tokens.Colors.elevatedCardBackground)
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
