#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import PaywallKit

@MainActor
struct PaywallPricingLayoutTests {
    private let products = [
        PaywallProduct(plan: .monthly, displayPrice: "249 kr", price: 249),
        PaywallProduct(plan: .yearly, displayPrice: "2 490 kr", price: 2490, monthlyEquivalentPrice: "207,50 kr"),
        PaywallProduct(plan: .lifetime, displayPrice: "4 990 kr", price: 4990),
    ]

    private func host(_ model: PaywallModel, loadingPlanCount: Int) -> NSHostingView<some View> {
        NSHostingView(
            rootView: PaywallPricing(model: model, loadingPlanCount: loadingPlanCount)
                .frame(width: 416)
                .environment(\.paywallStrings, PaywallStringTable { _ in "Monthly" }))
    }

    private func height(of view: NSView) -> CGFloat {
        view.layoutSubtreeIfNeeded()
        return view.fittingSize.height
    }

    @Test(arguments: [2, 3])
    func `plans arriving keep the height`(planCount: Int) async {
        let service = FakePaywallService()
        service.productsToReturn = Array(self.products.prefix(planCount))
        let model = PaywallModel(service: service)
        let view = self.host(model, loadingPlanCount: planCount)
        let loading = self.height(of: view)

        await model.appear()
        await Task.yield()

        #expect(self.height(of: view) == loading)
        // A placeholder far taller than the plans would keep the height by leaving a gap.
        let plansAlone = self.height(of: self.host(model, loadingPlanCount: planCount))
        #expect(abs(loading - plansAlone) <= 3, "loading \(loading), plans \(plansAlone)")
    }

    @Test
    func `plans failing to load keep the height`() async {
        let model = PaywallModel(service: FakePaywallService())
        let view = self.host(model, loadingPlanCount: 2)
        let loading = self.height(of: view)

        await model.appear()
        await Task.yield()

        #expect(model.productsUnavailable)
        #expect(self.height(of: view) == loading)
    }
}
#endif
