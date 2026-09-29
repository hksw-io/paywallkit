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
    @State private var displayed: Phase
    @State private var latestPhase: Phase
    @State private var labelFadeDone = false

    init(phase: Phase, title: String, checkmarkSymbol: String) {
        self.phase = phase
        self.title = title
        self.checkmarkSymbol = checkmarkSymbol
        self._displayed = State(initialValue: phase)
        self._latestPhase = State(initialValue: phase)
    }

    var body: some View {
        ZStack {
            Text(self.title)
                .opacity(self.displayed == .idle ? 1 : 0)
                .accessibilityHidden(self.displayed != .idle)

            ProgressView()
                .controlSize(.small)
                .opacity(self.displayed == .working ? 1 : 0)
                .accessibilityHidden(self.displayed != .working)

            Image(systemName: self.checkmarkSymbol)
                .symbolEffect(.drawOn, isActive: !self.reduceMotion && self.displayed != .success)
                .opacity(self.displayed == .success ? 1 : 0)
                .accessibilityLabel(self.strings(.complete))
                .accessibilityHidden(self.displayed != .success)
        }
        .onChange(of: self.phase) { _, newPhase in
            self.latestPhase = newPhase
            self.advance(to: newPhase)
        }
    }

    private func advance(to newPhase: Phase) {
        if self.reduceMotion {
            self.labelFadeDone = newPhase != .idle
            self.displayed = newPhase
            return
        }

        switch (self.displayed, newPhase) {
        case (.idle, .working), (.idle, .success):
            withAnimation(Tokens.Animations.quickFade, completionCriteria: .removed) {
                self.displayed = .working
            } completion: {
                self.labelFadeDone = true
                guard self.latestPhase == .success, self.displayed == .working else { return }
                withAnimation(Tokens.Animations.successPop) {
                    self.displayed = .success
                }
            }

        case (.working, .success):
            guard self.labelFadeDone else { return }
            withAnimation(Tokens.Animations.successPop) {
                self.displayed = .success
            }

        case (_, .idle):
            self.labelFadeDone = false
            withAnimation(Tokens.Animations.saveMorph) {
                self.displayed = .idle
            }

        default:
            withAnimation(Tokens.Animations.saveMorph) {
                self.displayed = newPhase
            }
        }
    }
}
#endif
