#if os(iOS) || os(macOS)
import SwiftUI

public struct PaywallView: View {
    let icon: Image
    let benefits: [PaywallBenefit]
    let highlightedBenefitID: String?
    let thanksLines: [Text]
    let privacyPolicy: URL
    let brand: PaywallBrand
    let wallpaperSymbols: [String]
    let hapticsEnabled: Bool
    let animatesDecorations: Bool
    let showsDismissButton: Bool
    let onDismiss: () -> Void

    @State private var model: PaywallModel
    @State private var strings: PaywallStringTable

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var contentAppeared = false
    @State private var sheetHeight = PaywallMetrics.spaciousHeight

    /// - Parameters:
    ///   - icon: The app icon shown as the hero and in the thank-you celebration.
    ///   - benefits: The rows under `.benefitsHeader`, in display order.
    ///   - highlightedBenefitID: The benefit the user just tried to use; it is tinted and announced.
    ///   - thanksLines: App-specific lines under `.thanksTitle` after a purchase.
    ///   - privacyPolicy: Linked in the footer next to Apple's standard Terms of Use.
    ///   - strings: Returns the app's localized text for each piece of copy. The kit ships none.
    ///   - brand: Base brand colour for glows, shadows and benefit tiles.
    ///   - brandLight: Lighter stop of the brand gradient.
    ///   - wallpaperSymbols: SF Symbols tiled faintly behind the sheet; empty draws none.
    ///   - hapticsEnabled: Pass the app's haptics preference; system settings still apply.
    ///   - animatesDecorations: Pass `false` to still ambient loops, for example under UI tests.
    public init(
        service: some PaywallService,
        icon: Image,
        benefits: [PaywallBenefit],
        highlightedBenefitID: String? = nil,
        thanksLines: [Text],
        privacyPolicy: URL,
        strings: @escaping @Sendable (PaywallString) -> String,
        brand: Color = .accentColor,
        brandLight: Color = .accentColor,
        wallpaperSymbols: [String] = [],
        hapticsEnabled: Bool = true,
        animatesDecorations: Bool = true,
        showsDismissButton: Bool = true,
        onDismiss: @escaping () -> Void)
    {
        self._model = State(initialValue: PaywallModel(service: service))
        self.icon = icon
        self.benefits = benefits
        self.highlightedBenefitID = highlightedBenefitID
        self.thanksLines = thanksLines
        self.privacyPolicy = privacyPolicy
        self._strings = State(initialValue: PaywallStringTable(strings))
        self.brand = PaywallBrand(base: brand, light: brandLight)
        self.wallpaperSymbols = wallpaperSymbols
        self.hapticsEnabled = hapticsEnabled
        self.animatesDecorations = animatesDecorations
        self.showsDismissButton = showsDismissButton
        self.onDismiss = onDismiss
    }

    public var body: some View {
        self.contentArea
            .environment(\.paywallSheetHeight, self.sheetHeight)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                guard PaywallMetrics.sheetHeightChanged(from: self.sheetHeight, to: height) else { return }
                self.sheetHeight = height
            }
            .background {
                PaywallBackdrop(isThanking: self.model.isThanking, symbols: self.wallpaperSymbols)
                    .padding(-200)
                    .ignoresSafeArea()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.sheet")
        #if os(macOS)
            .frame(width: PaywallMetrics.sheetWidth)
            .frame(maxHeight: PaywallMetrics.sheetMaxHeight)
        #else
            .presentationDetents([.large])
        #endif
            .onChange(of: self.reduceMotion, initial: true) { _, reduceMotion in
                self.model.reduceMotion = reduceMotion
            }
            .task {
                await self.model.appear()
            }
            .onDisappear { self.model.disappear() }
            .onAppear {
                guard !self.reduceMotion else {
                    self.contentAppeared = true
                    return
                }
                withAnimation(Tokens.Animations.smoothTransition) {
                    self.contentAppeared = true
                }
            }
            .onChange(of: self.model.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss {
                    self.onDismiss()
                }
            }
            .alert(
                self.strings(self.model.alert?.title ?? .purchaseFailedTitle),
                isPresented: .init(
                    get: { self.model.alert != nil },
                    set: {
                        if !$0 {
                            self.model.dismissAlert()
                        }
                    })) {
                Button(self.strings(.ok)) {
                    self.model.dismissAlert()
                }
            } message: {
                if let alert = self.model.alert {
                    Text(self.strings(alert.message))
                }
            }
            .environment(\.paywallBrand, self.brand)
            .environment(\.paywallHapticsEnabled, self.hapticsEnabled)
            .environment(\.paywallAnimatesDecorations, self.animatesDecorations)
            .environment(\.paywallStrings, self.strings)
    }

    private var contentArea: some View {
        self.layout
        #if !os(macOS)
            .frame(maxHeight: .infinity, alignment: .top)
        #endif
            .overlay(alignment: .topTrailing) {
                if self.showsDismissButton, !self.model.isThanking {
                    PaywallDismissButton(onDismiss: self.onDismiss)
                }
            }
            .opacity(self.model.isThanking ? 0 : 1)
            .allowsHitTesting(!self.model.isThanking)
            .accessibilityHidden(self.model.isThanking)
            .animation(
                self.reduceMotion ? nil : Tokens.Animations.thanksChromeFade,
                value: self.model.isThanking)
            .opacity(self.contentAppeared ? 1 : 0)
            .overlay {
                self.celebrationOverlay
            }
    }

    @ViewBuilder
    private var layout: some View {
        if self.dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                VStack(spacing: 0) {
                    self.scrollableContent

                    PaywallActionFooter(model: self.model, privacyPolicy: self.privacyPolicy)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            VStack(spacing: 0) {
                ViewThatFits(in: .vertical) {
                    self.scrollableContent

                    ScrollView {
                        self.scrollableContent
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }

                PaywallActionFooter(model: self.model, privacyPolicy: self.privacyPolicy)
            }
        }
    }

    private var scrollableContent: some View {
        let isAccessibilitySize = self.dynamicTypeSize.isAccessibilitySize
        let spacing = PaywallMetrics.sectionSpacing(for: self.sheetHeight)

        return VStack(spacing: 0) {
            Spacer(minLength: PaywallMetrics.heroTopPadding)

            PaywallHeroIcon(
                icon: self.iconView,
                size: isAccessibilitySize
                    ? PaywallMetrics.heroIconSize(for: PaywallMetrics.compactHeight)
                    : PaywallMetrics.heroIconSize(for: self.sheetHeight) + 4,
                showsOrnament: !isAccessibilitySize)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, PaywallMetrics.heroHorizontalPadding(showsDismissButton: self.showsDismissButton))

            Spacer(minLength: spacing)

            PaywallBenefitsSection(benefits: self.benefits, highlightedID: self.highlightedBenefitID)
                .padding(.horizontal, PaywallMetrics.horizontalPadding)

            Spacer(minLength: spacing)

            PaywallPricing(model: self.model)
                .padding(.horizontal, PaywallMetrics.horizontalPadding)
        }
        .padding(.bottom, spacing)
        .frame(maxWidth: .infinity)
    }

    private var iconView: some View {
        self.icon
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }

    private var celebrationOverlay: some View {
        ZStack {
            if self.model.isThanking {
                PaywallThanksView(icon: self.iconView, didRestore: self.model.didRestore, lines: self.thanksLines)
                    .transition(.opacity)
            }
        }
        .animation(self.reduceMotion ? nil : Tokens.Animations.thanksCenter, value: self.model.isThanking)
    }
}
#endif
