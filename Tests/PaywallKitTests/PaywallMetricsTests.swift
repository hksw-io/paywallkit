#if os(iOS) || os(macOS)
import CoreGraphics
import Testing
@testable import PaywallKit

struct PaywallMetricsTests {
    @Test
    func `sub-point height noise is not a change`() {
        #expect(!PaywallMetrics.sheetHeightChanged(from: 860.0000000000005, to: 860.0000000000002))
        #expect(!PaywallMetrics.sheetHeightChanged(from: 860, to: 861))
    }

    @Test
    func `a resized sheet is a change`() {
        #expect(PaywallMetrics.sheetHeightChanged(from: PaywallMetrics.spaciousHeight, to: 860))
        #expect(PaywallMetrics.sheetHeightChanged(from: 860, to: 850))
    }
}
#endif
