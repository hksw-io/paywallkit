#if os(iOS) || os(macOS)
import SwiftUI

enum PaywallMetrics {
    #if os(macOS)
        static let horizontalPadding: CGFloat = 32
        static let tierCornerRadius: CGFloat = 14
        static let radioOuterSize: CGFloat = 22
        static let radioInnerSize: CGFloat = 12
        static let footerSpacing: CGFloat = 20
        static let dismissClearance: CGFloat = 52
        static let sheetWidth: CGFloat = 480
        static let sheetMaxHeight: CGFloat = 720
    #else
        static let horizontalPadding: CGFloat = 24
        static let tierCornerRadius: CGFloat = 16
        static let radioOuterSize: CGFloat = 24
        static let radioInnerSize: CGFloat = 14
        static let footerSpacing: CGFloat = 16
        static let dismissClearance: CGFloat = 64
    #endif

    static let compactHeight: CGFloat = 667
    static let spaciousHeight: CGFloat = 956
    static let sheetHeightTolerance: CGFloat = 1

    static var heroTopPadding: CGFloat {
        #if os(macOS)
            return 22
        #else
            return 8
        #endif
    }

    static func heroIconSize(for height: CGFloat) -> CGFloat {
        #if os(macOS)
            return 56
        #else
            return self.scaled(48, 68, for: height)
        #endif
    }

    static func sectionSpacing(for height: CGFloat) -> CGFloat {
        #if os(macOS)
            return 16
        #else
            return self.scaled(12, 22, for: height)
        #endif
    }

    static func tierVerticalPadding(for height: CGFloat) -> CGFloat {
        #if os(macOS)
            return 11
        #else
            return self.scaled(11, 15, for: height)
        #endif
    }

    static func benefitRowVerticalPadding(for height: CGFloat) -> CGFloat {
        #if os(macOS)
            return Tokens.Spacing.xxSmall
        #else
            return self.scaled(5, 7, for: height)
        #endif
    }

    static func benefitFont(for height: CGFloat) -> Font {
        #if os(macOS)
            return Tokens.Fonts.compactBody
        #else
            return height >= 820 ? .body : .subheadline
        #endif
    }

    static func benefitTileSize(for height: CGFloat) -> CGFloat {
        #if os(macOS)
            return 22
        #else
            return self.scaled(26, 30, for: height)
        #endif
    }

    static func benefitRowSpacing(for height: CGFloat) -> CGFloat {
        #if os(macOS)
            return 4
        #else
            return self.scaled(0, 6, for: height)
        #endif
    }

    static func titleFont(for height: CGFloat) -> Font {
        #if os(macOS)
            return .title2.weight(.bold)
        #else
            return height < 700 ? .title3.weight(.bold) : .title2.weight(.bold)
        #endif
    }

    /// The measured height feeds the metrics that size the content, so a sub-point
    /// change must not be stored: floating-point noise would re-measure forever.
    static func sheetHeightChanged(from current: CGFloat, to measured: CGFloat) -> Bool {
        abs(measured - current) > self.sheetHeightTolerance
    }

    static func scaled(_ lower: CGFloat, _ upper: CGFloat, for height: CGFloat) -> CGFloat {
        let span = self.spaciousHeight - self.compactHeight
        let progress = min(max((height - self.compactHeight) / span, 0), 1)
        return lower + (upper - lower) * progress
    }

    static func heroHorizontalPadding(showsDismissButton: Bool) -> CGFloat {
        showsDismissButton
            ? max(self.horizontalPadding, self.dismissClearance)
            : self.horizontalPadding
    }
}

extension EnvironmentValues {
    @Entry var paywallSheetHeight: CGFloat = PaywallMetrics.spaciousHeight
}
#endif
