#if os(iOS) || os(macOS)
import SwiftUI

struct PaywallParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var opacity: Double
    var symbol: String
}

struct PaywallHeroIcon<Icon: View>: View {
    enum Mode {
        case ambient
        case celebration
    }

    private static var particleCount: Int {
        12
    }

    let icon: Icon
    let size: CGFloat
    var mode: Mode = .ambient
    var showsOrnament = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.paywallAnimatesDecorations) private var decorativeMotionEnabled
    @Environment(\.paywallBrand) private var brand

    @State private var float: CGFloat = 0
    @State private var pulse: CGFloat = 1
    @State private var pop: CGFloat = 1
    @State private var particles: [PaywallParticle] = []

    private var cornerRadius: CGFloat {
        self.size * 0.23
    }

    private var frameSize: CGFloat {
        self.size * 1.5
    }

    private var orbitalBase: CGFloat {
        self.size * 1.24
    }

    private var orbitalIncrement: CGFloat {
        self.size * 0.12
    }

    private var particleSize: CGFloat {
        max(7, self.size * 0.16)
    }

    private var particleRadiusRange: ClosedRange<CGFloat> {
        (self.size * 0.62) ... (self.size * 0.78)
    }

    var body: some View {
        ZStack {
            self.glow

            if self.showsOrnament {
                self.particlesLayer
                self.orbitalsLayer
            }

            self.icon
                .frame(width: self.size, height: self.size)
                .clipShape(RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous))
                .shadow(
                    color: self.brand.base.opacity(0.3),
                    radius: self.size * 0.25,
                    x: 0,
                    y: self.size * 0.09)
        }
        .frame(width: self.frameSize, height: self.frameSize)
        .scaleEffect(self.pulse)
        .scaleEffect(self.pop)
        .offset(y: self.float)
        .task {
            self.seedParticles()
            guard !self.reduceMotion, self.decorativeMotionEnabled else { return }
            if case .celebration = self.mode {
                await self.startCelebration()
            }
        }
    }

    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        self.brand.light.opacity(0.35),
                        self.brand.base.opacity(0.12),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: self.size * 1.35))
            .frame(width: self.size * 2.7, height: self.size * 2.7)
            .blur(radius: self.size * 0.22)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var orbitalsLayer: some View {
        self.orbitalRing(0)
        self.orbitalRing(1)
        self.orbitalRing(2)
    }

    private func orbitalRing(_ ring: Int) -> some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        self.brand.light.opacity(0.3),
                        self.brand.base.opacity(0.2),
                        self.brand.light.opacity(0.25),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing),
                lineWidth: 1)
            .frame(
                width: self.orbitalBase + CGFloat(ring) * self.orbitalIncrement,
                height: self.orbitalBase + CGFloat(ring) * self.orbitalIncrement)
            .opacity(0.5 - Double(ring) * 0.15)
            .rotationEffect(.degrees(Double(ring) * 30))
    }

    private var particlesLayer: some View {
        ZStack {
            if self.particles.count == Self.particleCount {
                self.particleView(0)
                self.particleView(1)
                self.particleView(2)
                self.particleView(3)
                self.particleView(4)
                self.particleView(5)
                self.particleView(6)
                self.particleView(7)
                self.particleView(8)
                self.particleView(9)
                self.particleView(10)
                self.particleView(11)
            }
        }
        .frame(width: self.frameSize, height: self.frameSize)
    }

    private func particleView(_ index: Int) -> some View {
        let particle = self.particles[index]
        return Image(systemName: particle.symbol)
            .font(.system(size: self.particleSize, weight: .medium))
            .foregroundStyle(self.brand.gradient)
            .opacity(particle.opacity)
            .scaleEffect(particle.scale)
            .offset(x: particle.x, y: particle.y)
            .accessibilityHidden(true)
    }

    private func seedParticles() {
        guard self.particles.isEmpty else { return }
        let symbols = ["sparkle", "star.fill", "circle.fill"]
        self.particles = (0 ..< Self.particleCount).map { index in
            let angle = (Double(index) / Double(Self.particleCount)) * 2.0 * .pi
            let radius = CGFloat.random(in: self.particleRadiusRange)
            return PaywallParticle(
                x: cos(angle) * radius,
                y: sin(angle) * radius,
                scale: CGFloat.random(in: 0.5 ... 1.0),
                opacity: Double.random(in: 0.3 ... 0.7),
                symbol: symbols[index % symbols.count])
        }
    }

    private func startCelebration() async {
        withAnimation(Tokens.Animations.successPop) {
            self.pop = 1.05
        }
        try? await Task.sleep(for: .seconds(0.33))
        withAnimation(Tokens.Animations.thanksIconSettle) {
            self.pop = 1
        }
        withAnimation(Tokens.Animations.celebrationBreath.repeatForever(autoreverses: true)) {
            self.float = -4
            self.pulse = 1.015
        }
    }
}

enum PaywallTitleStyle {
    static let gradient = LinearGradient(
        colors: [.primary, Color.primary.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing)
}

struct PaywallActionFooter: View {
    let model: PaywallModel
    let privacyPolicy: URL

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.paywallHapticsEnabled) private var hapticEnabled
    @Environment(\.paywallStrings) private var strings

    private var arrowSwayPhases: [CGFloat] {
        self.reduceMotion ? [0] : [0, 5]
    }

    private var phase: PaywallButtonMorph.Phase {
        if self.model.didSucceed {
            .success
        } else if self.model.isPurchasing {
            .working
        } else {
            .idle
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            self.ctaButton
                .padding(.horizontal, PaywallMetrics.horizontalPadding)

            Group {
                if self.model.isPurchasePending {
                    Text(self.strings(.pending))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else if self.model.isPurchasing {
                    self.caption(self.strings(.purchasing), style: .primary)
                } else {
                    self.caption(
                        self.strings(
                            PaywallCopy.reassurance(for: self.model.selectedPlan, product: self.model.selectedProduct)),
                        style: .secondary)
                }
            }
            .padding(.top, 6)
            .padding(.horizontal, PaywallMetrics.horizontalPadding)

            PaywallFooterLinks(model: self.model, privacyPolicy: self.privacyPolicy)
                .padding(.top, 8)
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func caption(_ text: String, style: HierarchicalShapeStyle) -> some View {
        let copy = Text(text)
            .font(.caption)
            .foregroundStyle(style)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

        if self.dynamicTypeSize.isAccessibilitySize {
            copy
        } else {
            copy.lineLimit(2, reservesSpace: true)
        }
    }

    private var ctaButton: some View {
        let isAccessibilitySize = self.dynamicTypeSize.isAccessibilitySize
        let callToAction = PaywallCopy.callToAction(for: self.model.selectedPlan, product: self.model.selectedProduct)

        return Button {
            Task { await self.model.purchase() }
        } label: {
            HStack(spacing: 8) {
                PaywallButtonMorph(
                    phase: self.phase,
                    title: self.strings(callToAction),
                    checkmarkSymbol: "checkmark.seal.fill")
                    .font(.headline.weight(.semibold))
                    .environment(\.colorScheme, .dark)

                if self.phase == .idle, !isAccessibilitySize {
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.semibold))
                        .phaseAnimator(
                            self.arrowSwayPhases,
                            content: { arrow, offset in
                                arrow.offset(x: offset)
                            },
                            animation: { _ in
                                Tokens.Animations.ctaArrowSway
                            })
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .transition(.opacity)
            .lineLimit(isAccessibilitySize ? nil : 1)
            .minimumScaleFactor(isAccessibilitySize ? 1 : 0.7)
            .multilineTextAlignment(.center)
            .id(callToAction)
            .animation(self.reduceMotion ? nil : Tokens.Animations.smoothTransition, value: callToAction)
            .animation(self.reduceMotion ? nil : Tokens.Animations.saveMorph, value: self.phase)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(.accentColor)
        .disabled(!self.model.isPurchaseButtonEnabled)
        .allowsHitTesting(!self.model.isRestoring)
        .sensoryFeedback(.success, trigger: self.phase == .success) { _, isSuccess in
            self.hapticEnabled && isSuccess
        }
    }
}

struct PaywallFooterLinks: View {
    let model: PaywallModel
    let privacyPolicy: URL

    @Environment(\.paywallStrings) private var strings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PaywallMetrics.footerSpacing) {
                self.termsLink
                self.separator
                self.privacyLink
                self.separator
                self.restoreButton
            }

            VStack(spacing: 12) {
                self.termsLink
                self.privacyLink
                self.restoreButton
            }
        }
    }

    @ViewBuilder
    private var termsLink: some View {
        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
            Link(self.strings(.termsOfUse), destination: url)
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }

    private var privacyLink: some View {
        Link(self.strings(.privacyPolicy), destination: self.privacyPolicy)
            .foregroundStyle(.secondary)
            .font(.footnote)
    }

    private var separator: some View {
        Circle()
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 3, height: 3)
            .accessibilityHidden(true)
    }

    private var restoreButton: some View {
        Button {
            Task { await self.model.restore() }
        } label: {
            HStack(spacing: 6) {
                Text(self.strings(.restore))

                if self.model.isRestoring {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
        .foregroundStyle(.secondary)
        .font(.footnote)
        .disabled(self.model.isPurchasing || self.model.isRestoring)
        .accessibilityHint(self.strings(.restoreHint))
    }
}

struct PaywallDismissButton: View {
    let onDismiss: () -> Void

    @Environment(\.paywallStrings) private var strings

    var body: some View {
        #if os(macOS)
            Button(self.strings(.notNow), action: self.onDismiss)
                .keyboardShortcut(.cancelAction)
                .padding(.trailing, 16)
                .padding(.top, 12)
        #else
            Button(role: .close, action: self.onDismiss) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(self.strings(.close))
            .padding(.trailing, 16)
            .padding(.top, 16)
        #endif
    }
}
#endif
