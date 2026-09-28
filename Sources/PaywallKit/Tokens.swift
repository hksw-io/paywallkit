#if os(iOS) || os(macOS)
import SwiftUI

enum Tokens {
    enum Animations {
        static let smoothTransition: Animation = .smooth(duration: 0.3)
        static let quickFade: Animation = .easeInOut(duration: 0.2)
        static let ctaArrowSway: Animation = .easeInOut(duration: 0.8)
        static let felt: Animation = .spring(duration: 0.32, bounce: 0.16)
        static let saveMorph: Animation = .smooth(duration: 0.24)
        static let successPop: Animation = .spring(duration: 0.32, bounce: 0.28)
        static let thanksChromeFade: Animation = .smooth(duration: 0.55)
        static let thanksCopyLand: Animation = .smooth(duration: 1.0).delay(0.95)
        static let thanksIconSettle: Animation = .smooth(duration: 0.68)
        static let thanksCenter: Animation = .smooth(duration: 0.60).delay(0.20)
        static let thanksCopyLandTrail: Animation = .smooth(duration: 1.0).delay(1.13)
        static let celebrationDrift: Animation = .easeInOut(duration: 8)
        static let celebrationBreath: Animation = .easeInOut(duration: 3.5)
        static let thanksSheen: Animation = .easeInOut(duration: 0.8)
        static let skeletonShimmer: Animation = .easeInOut(duration: 1.1).repeatForever(autoreverses: false)
        static let focusHalo: Animation = .linear(duration: 12).repeatForever(autoreverses: false)
        static let selectionPop: Animation = .spring(duration: 0.26, bounce: 0.22)
    }

    enum Colors {
        #if os(iOS)
            static let background = Color(.systemBackground)
            static let elevatedCardBackground = Color(.secondarySystemGroupedBackground)
            static let subtleFill = Color(.systemGray5)
            static let separator = Color(.separator)
            static let subtleShadow = Color(.label).opacity(0.1)
        #else
            static let background = Color(nsColor: .windowBackgroundColor)
            static let elevatedCardBackground = Color(nsColor: .controlBackgroundColor)
            static let subtleFill = Color(nsColor: .separatorColor)
            static let separator = Color(nsColor: .separatorColor)
            static let subtleShadow = Color(nsColor: .shadowColor).opacity(0.1)
        #endif
    }

    enum Spacing {
        static let xxSmall: CGFloat = 4
        static let medium: CGFloat = 12
    }

    enum Radius {
        static let medium: CGFloat = 12
        static let xLarge: CGFloat = 20
    }

    enum Fonts {
        #if os(macOS)
            static let compactBody: Font = .body
        #else
            static let compactBody: Font = .subheadline
        #endif
    }
}

struct PaywallBrand: Equatable {
    var base: Color
    var light: Color

    var gradient: LinearGradient {
        LinearGradient(colors: [self.light, self.base], startPoint: .top, endPoint: .bottom)
    }
}

extension EnvironmentValues {
    @Entry var paywallBrand = PaywallBrand(base: .accentColor, light: .accentColor)
    @Entry var paywallHapticsEnabled = true
    @Entry var paywallAnimatesDecorations = true
}
#endif
