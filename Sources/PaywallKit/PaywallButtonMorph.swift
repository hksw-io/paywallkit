#if os(iOS) || os(macOS)
import SwiftUI

struct PaywallButtonMorph: View {
    enum Phase: Equatable {
        case idle
        case working
        case success
    }

    let phase: Phase
    let title: String
    let checkmarkSymbol: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.paywallStrings) private var strings

    var body: some View {
        ZStack {
            Text(self.title)
                .opacity(self.phase == .idle ? 1 : 0)
                .accessibilityHidden(self.phase != .idle)

            ProgressView()
                .controlSize(.small)
                .opacity(self.phase == .working ? 1 : 0)
                .accessibilityHidden(self.phase != .working)

            Image(systemName: self.checkmarkSymbol)
                .symbolEffect(.drawOn, isActive: !self.reduceMotion && self.phase != .success)
                .opacity(self.phase == .success ? 1 : 0)
                .accessibilityLabel(self.strings(.complete))
                .accessibilityHidden(self.phase != .success)
        }
        .animation(self.reduceMotion ? nil : Tokens.Animations.quickFade, value: self.phase)
    }
}
#endif
