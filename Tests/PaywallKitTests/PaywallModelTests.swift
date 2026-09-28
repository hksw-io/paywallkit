#if os(iOS) || os(macOS)
import Foundation
import Observation
import StoreKit
import Synchronization
import Testing
@testable import PaywallKit

@MainActor
@Observable
final class FakePaywallService: PaywallService {
    var entitlement: PaywallEntitlement
    var productsToReturn: [PaywallProduct] = []
    var canMakePayments = true
    var purchaseError: Error?
    var restoreError: Error?
    var entitlementAfterRestore: PaywallEntitlement?
    var loadProductsCallCount = 0
    var restoreCallCount = 0
    var purchasedPlans: [PaywallPlan] = []

    init(entitlement: PaywallEntitlement = .free) {
        self.entitlement = entitlement
    }

    var products: [PaywallProduct] {
        self.productsToReturn
    }

    func loadProducts(forceRefresh _: Bool) async {
        self.loadProductsCallCount += 1
    }

    func purchase(_ plan: PaywallPlan) async throws {
        if let error = self.purchaseError {
            throw error
        }
        self.purchasedPlans.append(plan)
        self.entitlement = .entitled
    }

    func restorePurchases() async throws {
        self.restoreCallCount += 1
        if let error = self.restoreError {
            throw error
        }
        if let entitlement = self.entitlementAfterRestore {
            self.entitlement = entitlement
        }
    }
}

struct TestError: Error {}

final class SleepLog: Sendable {
    private let log = Mutex<[Duration]>([])

    var durations: [Duration] {
        self.log.withLock { $0 }
    }

    func sleep(_ duration: Duration) async throws {
        self.log.withLock { $0.append(duration) }
    }
}

@MainActor
struct PaywallModelTests {
    private let sleeps = SleepLog()

    private func makeModel(
        service: FakePaywallService = FakePaywallService(),
        purchasable: Bool = true,
        reduceMotion: Bool = false) -> PaywallModel
    {
        let sleeps = self.sleeps
        let model = PaywallModel(service: service) { try await sleeps.sleep($0) }
        model.reduceMotion = reduceMotion
        if purchasable {
            model.products = PaywallPlan.allCases.map(Self.product)
            model.hasLoadedProducts = true
        }
        return model
    }

    private static func product(_ plan: PaywallPlan) -> PaywallProduct {
        PaywallProduct(plan: plan, displayPrice: "$9.99")
    }

    private func settle(until condition: () -> Bool) async {
        for _ in 0 ..< 1000 where !condition() {
            await Task.yield()
        }
    }

    @Test
    func `already active access dismisses immediately`() async {
        let service = FakePaywallService(entitlement: .entitled)
        let model = self.makeModel(service: service)
        await model.appear()
        #expect(model.shouldDismiss)
        #expect(!model.isThanking)
        #expect(service.loadProductsCallCount == 0)
    }

    @Test
    func `access that was only unknown closes without a celebration`() async {
        let service = FakePaywallService(entitlement: .unknown)
        let model = self.makeModel(service: service, purchasable: false)
        await model.appear()
        service.entitlement = .entitled
        await self.settle { model.shouldDismiss }
        #expect(model.shouldDismiss)
        #expect(!model.didSucceed)
        #expect(!model.isThanking)
        model.disappear()
    }

    @Test
    func `access granted after a free status still celebrates`() async {
        let service = FakePaywallService(entitlement: .free)
        let model = self.makeModel(service: service, purchasable: false)
        await model.appear()
        service.entitlement = .entitled
        await self.settle { model.didSucceed }
        #expect(model.didSucceed)
        await model.celebration?.value
        #expect(model.isThanking)
        #expect(model.shouldDismiss)
        model.disappear()
    }

    @Test
    func `duplicate entitlement success preserves restore completion`() async {
        let model = self.makeModel()
        model.restoreFinished(.entitled)
        await model.celebration?.value
        model.entitlementGranted()
        model.purchaseSucceeded()
        #expect(model.didRestore)
        #expect(model.didSucceed)
        #expect(model.shouldDismiss)
        #expect(!model.canPurchase)
        #expect(self.sleeps.durations.count == 2)
    }

    @Test
    func `the purchase button stays enabled through a purchase and disables when nothing can be bought`() {
        let model = self.makeModel()
        #expect(model.isPurchaseButtonEnabled)
        model.isPurchasing = true
        #expect(!model.canPurchase)
        #expect(model.isPurchaseButtonEnabled)
        model.isPurchasing = false
        model.didSucceed = true
        #expect(model.isPurchaseButtonEnabled)
        model.didSucceed = false
        model.isPurchasePending = true
        #expect(!model.isPurchaseButtonEnabled)
        model.isPurchasePending = false
        model.products = []
        #expect(!model.isPurchaseButtonEnabled)
    }

    @Test
    func `plan selection updates state`() {
        let model = self.makeModel()
        model.select(.monthly)
        #expect(model.selectedPlan == .monthly)
        model.select(.lifetime)
        #expect(model.selectedPlan == .lifetime)
    }

    @Test
    func `choosing a plan during a purchase keeps the selected plan`() {
        let model = self.makeModel()
        model.isPurchasing = true
        model.select(.monthly)
        #expect(model.selectedPlan == .yearly)
    }

    @Test
    func `on appear loads products into state`() async {
        let yearly = PaywallProduct(
            plan: .yearly,
            displayPrice: "$59.99",
            monthlyEquivalentPrice: "$4.99",
            introductoryOfferText: "Free trial")
        let service = FakePaywallService()
        service.productsToReturn = [yearly]
        let model = self.makeModel(service: service, purchasable: false)

        #expect(model.isLoadingProducts)
        await model.appear()

        #expect(model.products == [yearly])
        #expect(!model.isLoadingProducts)
        #expect(service.loadProductsCallCount == 1)
        model.disappear()
    }

    @Test
    func `failed product load offers retry and blocks purchasing`() async {
        let service = FakePaywallService()
        let model = self.makeModel(service: service, purchasable: false)

        await model.appear()
        #expect(model.hasLoadedProducts)
        #expect(model.productsUnavailable)
        #expect(!model.canPurchase)

        let yearly = Self.product(.yearly)
        service.productsToReturn = [yearly]
        await model.retryLoadProducts()

        #expect(model.products == [yearly])
        #expect(!model.productsUnavailable)
        #expect(model.canPurchase)
        #expect(service.loadProductsCallCount == 2)
        model.disappear()
    }

    @Test
    func `payments disabled hides plans and blocks purchasing`() async {
        let service = FakePaywallService()
        service.productsToReturn = [Self.product(.yearly)]
        service.canMakePayments = false
        let model = self.makeModel(service: service, purchasable: false)

        await model.appear()
        #expect(model.paymentsUnavailable)
        #expect(!model.productsUnavailable)
        #expect(!model.canPurchase)

        await model.purchase()
        #expect(service.purchasedPlans.isEmpty)
        model.disappear()
    }

    @Test
    func `partial product response selects a valid fallback in display order`() async {
        let monthly = Self.product(.monthly)
        let lifetime = Self.product(.lifetime)
        let service = FakePaywallService()
        service.productsToReturn = [lifetime, monthly]
        let model = self.makeModel(service: service, purchasable: false)

        await model.appear()
        #expect(model.products == [monthly, lifetime])
        #expect(model.selectedPlan == .monthly)
        #expect(model.canPurchase)
        model.disappear()
    }

    @Test
    func `unavailable plan cannot be selected or purchased`() async {
        let service = FakePaywallService()
        let model = self.makeModel(service: service, purchasable: false)
        model.productsLoaded([Self.product(.yearly)], canMakePayments: true)

        model.select(.monthly)
        #expect(model.selectedPlan == .yearly)

        model.selectedPlan = .monthly
        await model.purchase()
        #expect(service.purchasedPlans.isEmpty)
    }

    @Test
    func `payment restriction reported during purchase shows a specific error`() async {
        let service = FakePaywallService()
        service.purchaseError = PaywallError.paymentsNotAllowed
        let model = self.makeModel(service: service)

        await model.purchase()
        #expect(!model.isPurchasing)
        #expect(!model.canMakePayments)
        #expect(model.alert == PaywallModel.Alert(
            title: localized("paywall.payments.unavailable.title"),
            message: localized("paywall.payments.unavailable.message")))
        #expect(model.paymentsUnavailable)

        model.dismissAlert()
        #expect(model.alert == nil)
        #expect(model.paymentsUnavailable)
        #expect(!model.canPurchase)
    }

    @Test
    func `purchase success celebrates then dismisses`() async {
        let service = FakePaywallService()
        let model = self.makeModel(service: service)

        await model.purchase()
        #expect(!model.isPurchasing)
        #expect(model.didSucceed)
        #expect(!model.didRestore)
        #expect(!model.isThanking)
        #expect(!model.shouldDismiss)

        await model.celebration?.value
        #expect(model.isThanking)
        #expect(model.shouldDismiss)
        #expect(self.sleeps.durations == [PaywallModel.thanksLead, PaywallModel.thanksDwell])
        #expect(service.purchasedPlans == [.yearly])
    }

    @Test
    func `purchase success with reduce motion still shows thanks before dismiss`() async {
        let model = self.makeModel(reduceMotion: true)

        await model.purchase()
        await model.celebration?.value
        #expect(model.isThanking)
        #expect(model.shouldDismiss)
        #expect(self.sleeps.durations == [.zero, PaywallModel.thanksDwellReduced])
    }

    @Test(arguments: [
        PaywallError.cancelled as any Error,
        StoreKitError.userCancelled,
        CancellationError(),
    ])
    func `a cancelled purchase shows no error`(error: any Error) async {
        let service = FakePaywallService()
        service.purchaseError = error
        let model = self.makeModel(service: service)

        await model.purchase()
        #expect(!model.isPurchasing)
        #expect(model.alert == nil)
        #expect(!model.shouldDismiss)
    }

    @Test(arguments: [
        (PaywallError.productNotFound as any Error, "paywall.error.productNotFound"),
        (PaywallError.verificationFailed, "paywall.error.verificationFailed"),
        (PaywallError.failed, "paywall.error.generic"),
        (TestError(), "paywall.error.generic"),
    ])
    func `a failed purchase names the failure`(error: any Error, messageKey: String) async {
        let service = FakePaywallService()
        service.purchaseError = error
        let model = self.makeModel(service: service)

        await model.purchase()
        #expect(!model.isPurchasing)
        #expect(model.alert == PaywallModel.Alert(
            title: localized("paywall.error.title"),
            message: localized(String.LocalizationValue(messageKey))))
    }

    @Test
    func `purchase pending shows pending message`() async {
        let service = FakePaywallService()
        service.purchaseError = PaywallError.pending
        let model = self.makeModel(service: service)

        await model.purchase()
        #expect(model.isPurchasePending)
        #expect(model.alert == PaywallModel.Alert(
            title: localized("paywall.error.pending.title"),
            message: localized("paywall.error.pending")))
    }

    @Test
    func `pending purchase stays pending after acknowledgment until approval celebrates`() async {
        let service = FakePaywallService()
        service.purchaseError = PaywallError.pending
        service.productsToReturn = [Self.product(.yearly)]
        let model = self.makeModel(service: service, purchasable: false, reduceMotion: true)

        await model.appear()
        await model.purchase()
        #expect(model.alert != nil)
        model.dismissAlert()
        #expect(model.isPurchasePending)
        #expect(!model.canPurchase)

        service.entitlement = .entitled
        await self.settle { model.didSucceed }
        await model.celebration?.value
        #expect(model.didSucceed)
        #expect(model.shouldDismiss)
        #expect(!model.isPurchasePending)
        model.disappear()
    }

    @Test
    func `purchase without an active entitlement shows an error instead of celebrating`() async {
        let service = FakePaywallService()
        service.purchaseError = PaywallError.notActivated
        let model = self.makeModel(service: service)

        await model.purchase()
        #expect(model.alert == PaywallModel.Alert(
            title: localized("paywall.error.title"),
            message: localized("paywall.error.entitlementNotActive")))
        #expect(!model.didSucceed)
        #expect(model.celebration == nil)
    }

    @Test
    func `dismiss error clears alert`() {
        let model = self.makeModel()
        model.alert = PaywallModel.Alert(title: "title", message: "error")
        model.dismissAlert()
        #expect(model.alert == nil)
    }

    @Test
    func `restore success with active access celebrates then dismisses`() async {
        let service = FakePaywallService()
        service.entitlementAfterRestore = .entitled
        let model = self.makeModel(service: service)

        await model.restore()
        #expect(!model.isRestoring)
        #expect(model.didRestore)
        #expect(model.didSucceed)
        #expect(!model.shouldDismiss)

        await model.celebration?.value
        #expect(model.isThanking)
        #expect(model.shouldDismiss)
    }

    @Test
    func `restore without access shows no purchases message`() async {
        let model = self.makeModel()

        await model.restore()
        #expect(!model.isRestoring)
        #expect(model.alert == PaywallModel.Alert(
            title: localized("paywall.error.noPurchasesToRestore.title"),
            message: localized("paywall.error.noPurchasesToRestore")))
        #expect(!model.shouldDismiss)
    }

    @Test
    func `restore failure shows error`() async {
        let service = FakePaywallService()
        service.restoreError = TestError()
        let model = self.makeModel(service: service)

        await model.restore()
        #expect(!model.isRestoring)
        #expect(model.alert == PaywallModel.Alert(
            title: localized("paywall.error.restoreFailed.title"),
            message: localized("paywall.error.restoreFailed")))
    }

    @Test
    func `cancelling a restore resets without an alert`() async {
        let service = FakePaywallService()
        service.restoreError = StoreKitError.userCancelled
        let model = self.makeModel(service: service)

        await model.restore()
        #expect(!model.isRestoring)
        #expect(model.alert == nil)
    }

    @Test
    func `purchase blocked while already purchasing`() async {
        let service = FakePaywallService()
        let model = self.makeModel(service: service)
        model.isPurchasing = true

        await model.purchase()
        #expect(service.purchasedPlans.isEmpty)
        #expect(model.isPurchasing)
    }

    @Test
    func `restore blocked while restoring`() async {
        let service = FakePaywallService()
        let model = self.makeModel(service: service)
        model.isRestoring = true

        await model.restore()
        #expect(service.restoreCallCount == 0)
        #expect(model.isRestoring)
    }

    @Test
    func `purchase blocked while restoring`() async {
        let service = FakePaywallService()
        let model = self.makeModel(service: service)
        model.isRestoring = true

        await model.purchase()
        #expect(service.purchasedPlans.isEmpty)
        #expect(!model.isPurchasing)
    }

    @Test
    func `purchase blocked after success runs a single thanks timeline`() async {
        let service = FakePaywallService()
        let model = self.makeModel(service: service)

        await model.purchase()
        await model.purchase()
        #expect(service.purchasedPlans == [.yearly])

        await model.celebration?.value
        #expect(model.shouldDismiss)
        #expect(self.sleeps.durations == [PaywallModel.thanksLead, PaywallModel.thanksDwell])
    }

    @Test
    func `restore blocked while thanks celebration is active`() async {
        let service = FakePaywallService()
        let model = self.makeModel(service: service)

        await model.purchase()
        await model.restore()
        #expect(service.restoreCallCount == 0)
        #expect(!model.isRestoring)

        await model.celebration?.value
        #expect(model.shouldDismiss)
    }
}
#endif
