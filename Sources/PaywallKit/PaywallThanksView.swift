#if os(iOS) || os(macOS)
import SwiftUI

struct PaywallThanksView<Icon: View>: View {
    let icon: Icon
    let didRestore: Bool
    let lines: [Text]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.paywallSheetHeight) private var sheetHeight

    @State private var titleShown = false
    @State private var subtitleShown = false
    @State private var sheenPhase: CGFloat = 0

    private var titleText: String {
        self.didRestore
            ? localized("paywall.restore.title")
            : localized("paywall.thanks.title")
    }

    private var titleFont: Font {
        PaywallMetrics.titleFont(for: self.sheetHeight)
    }

    var body: some View {
        VStack(spacing: 16) {
            PaywallHeroIcon(
                icon: self.icon,
                size: PaywallMetrics.heroIconSize(for: self.sheetHeight) + 8,
                mode: .celebration,
                showsOrnament: false)

            VStack(spacing: 8) {
                Text(self.titleText)
                    .font(self.titleFont)
                    .foregroundStyle(PaywallTitleStyle.gradient)
                    .overlay { self.titleSheen }
                    .opacity(self.titleShown ? 1 : 0)

                VStack(spacing: 3) {
                    if self.didRestore {
                        Text(localized("paywall.restore.subtitle"))
                    } else {
                        ForEach(self.lines.indices, id: \.self) { index in
                            self.lines[index]
                        }
                    }
                }
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(self.subtitleShown ? 1 : 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, PaywallMetrics.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await self.reveal()
        }
    }

    @ViewBuilder
    private var titleSheen: some View {
        if !self.reduceMotion {
            GeometryReader { geometry in
                let width = geometry.size.width
                LinearGradient(
                    colors: [.clear, Color.accentColor.opacity(0.55), .clear],
                    startPoint: .leading,
                    endPoint: .trailing)
                    .frame(width: width * 0.45)
                    .offset(x: -width * 0.45 + self.sheenPhase * width * 1.45)
            }
            .mask(Text(self.titleText).font(self.titleFont))
            .allowsHitTesting(false)
        }
    }

    private func reveal() async {
        var announcement = AttributedString(self.titleText)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()

        guard !self.reduceMotion else {
            self.titleShown = true
            self.subtitleShown = true
            return
        }

        withAnimation(Tokens.Animations.thanksCopyLand) {
            self.titleShown = true
        }
        withAnimation(Tokens.Animations.thanksCopyLandTrail) {
            self.subtitleShown = true
        }

        try? await Task.sleep(for: .seconds(1.9))
        withAnimation(Tokens.Animations.thanksSheen) {
            self.sheenPhase = 1
        }
    }
}
#endif
