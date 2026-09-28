#if os(iOS) || os(macOS)
import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class PaywallModel {
    struct Alert: Equatable {
        var title: String
        var message: String
    }

    static let thanksLead: Duration = .milliseconds(320)
    static let thanksDwell: Duration = .milliseconds(3600)
    static let thanksDwellReduced: Duration = .milliseconds(3000)

    @ObservationIgnored let service: any PaywallService
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored private var entitlementObservation: Task<Void, Never>?
    @ObservationIgnored private(set) var celebration: Task<Void, Never>?

    var selectedPlan: PaywallPlan = .yearly
    var isPurchasePending = false
    var isPurchasing = false
    var isRestoring = false
    var didSucceed = false
    var didRestore = false
    var alert: Alert?
    var shouldDismiss = false
    var isThanking = false
    var products: [PaywallProduct] = []
    var hasLoadedProducts = false
    var canMakePayments = true

    init(
        service: any PaywallService,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) })
    {
        self.service = service
        self.sleep = sleep
    }

    var paymentsUnavailable: Bool {
        self.hasLoadedProducts && !self.canMakePayments
    }

    var productsUnavailable: Bool {
        self.hasLoadedProducts && self.canMakePayments && self.products.isEmpty
    }

    var isLoadingProducts: Bool {
        !self.hasLoadedProducts
    }

    var canPurchase: Bool {
        self.canMakePayments
            && self.product(for: self.selectedPlan) != nil
            && !self.isPurchasePending
            && !self.didSucceed
            && !self.isPurchasing
            && !self.isRestoring
    }

    var isPurchaseButtonEnabled: Bool {
        self.canPurchase || self.isPurchasing || self.didSucceed
    }

    var selectedProduct: PaywallProduct? {
        self.product(for: self.selectedPlan)
    }

    func product(for plan: PaywallPlan) -> PaywallProduct? {
        self.products.first { $0.plan == plan }
    }

    func appear() async {
        if self.service.entitlement == .entitled {
            self.shouldDismiss = true
            return
        }
        self.observeEntitlement()
        await self.loadProducts(forceRefresh: false)
    }

    func disappear() {
        self.isPurchasePending = false
        self.entitlementObservation?.cancel()
        self.entitlementObservation = nil
    }

    func retryLoadProducts() async {
        await self.loadProducts(forceRefresh: true)
    }

    func select(_ plan: PaywallPlan) {
        guard self.canMakePayments, !self.isPurchasing, !self.didSucceed,
              self.product(for: plan) != nil else { return }
        self.selectedPlan = plan
    }

    func purchase() async {
        guard self.canPurchase, !self.didSucceed else { return }
        self.isPurchasing = true
        do {
            try await self.service.purchase(self.selectedPlan)
            self.purchaseSucceeded()
        } catch {
            self.purchaseFailed(error)
        }
    }

    func restore() async {
        guard !self.isPurchasing, !self.isRestoring, !self.didSucceed else { return }
        self.isRestoring = true
        do {
            try await self.service.restorePurchases()
            self.restoreFinished(self.service.entitlement)
        } catch {
            self.restoreFailed(error)
        }
    }

    func dismissAlert() {
        self.alert = nil
    }

    func productsLoaded(_ loaded: [PaywallProduct], canMakePayments: Bool) {
        self.products = PaywallPlan.allCases.compactMap { plan in
            loaded.first { $0.plan == plan }
        }
        self.canMakePayments = canMakePayments
        self.hasLoadedProducts = true
        if self.product(for: self.selectedPlan) == nil,
           let fallback = self.product(for: .yearly)?.plan ?? self.products.first?.plan
        {
            self.selectedPlan = fallback
        }
    }

    func entitlementGranted() {
        guard !self.isPurchasing, !self.isRestoring else { return }
        self.finishPurchase()
    }

    func accessConfirmed() {
        guard !self.isPurchasing, !self.isRestoring, !self.didSucceed else { return }
        self.shouldDismiss = true
    }

    func purchaseSucceeded() {
        self.finishPurchase()
    }

    func purchaseFailed(_ error: Error) {
        if self.service.entitlement == .entitled {
            self.finishPurchase()
            return
        }
        guard !self.didSucceed else { return }
        self.isPurchasing = false
        if case .pending = error as? PaywallError {
            self.isPurchasePending = true
        }
        if case .paymentsNotAllowed = error as? PaywallError {
            self.canMakePayments = false
        }
        self.alert = Self.alert(for: error)
    }

    func restoreFinished(_ entitlement: PaywallEntitlement) {
        guard !self.didSucceed else { return }
        self.isRestoring = false
        if entitlement == .entitled {
            self.finishPurchase(restored: true)
        } else {
            self.alert = Alert(
                title: localized("paywall.error.noPurchasesToRestore.title"),
                message: localized("paywall.error.noPurchasesToRestore"))
        }
    }

    func restoreFailed(_ error: Error) {
        if self.service.entitlement == .entitled {
            self.finishPurchase(restored: true)
            return
        }
        guard !self.didSucceed else { return }
        self.isRestoring = false
        guard !Self.isCancellation(error) else { return }
        self.alert = Alert(
            title: localized("paywall.error.restoreFailed.title"),
            message: localized("paywall.error.restoreFailed"))
    }

    private func loadProducts(forceRefresh: Bool) async {
        await self.service.loadProducts(forceRefresh: forceRefresh)
        self.productsLoaded(self.service.products, canMakePayments: self.service.canMakePayments)
    }

    private func observeEntitlement() {
        self.entitlementObservation?.cancel()
        let entitlements = Observations { @MainActor [weak self] in
            self?.service.entitlement ?? .unknown
        }
        var sawFree = self.service.entitlement == .free
        self.entitlementObservation = Task { [weak self] in
            for await entitlement in entitlements {
                guard !Task.isCancelled, let self else { return }
                switch entitlement {
                case .free:
                    sawFree = true
                case .unknown:
                    continue
                case .entitled:
                    if sawFree {
                        self.entitlementGranted()
                    } else {
                        self.accessConfirmed()
                    }
                    return
                }
            }
        }
    }

    private func finishPurchase(restored: Bool = false) {
        guard !self.didSucceed else { return }
        self.isPurchasing = false
        self.isRestoring = false
        self.isPurchasePending = false
        self.alert = nil
        self.didRestore = restored
        self.didSucceed = true
        self.celebrate()
    }

    private func celebrate() {
        let lead: Duration = self.reduceMotion ? .zero : Self.thanksLead
        let dwell: Duration = self.reduceMotion ? Self.thanksDwellReduced : Self.thanksDwell
        let sleep = self.sleep
        self.celebration = Task {
            do {
                try await sleep(lead)
                self.isThanking = true
                try await sleep(dwell)
                self.shouldDismiss = true
            } catch {
                return
            }
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if case .userCancelled = error as? StoreKitError {
            return true
        }
        return error as? PaywallError == .cancelled
    }

    private static func alert(for error: Error) -> Alert? {
        guard !self.isCancellation(error) else { return nil }
        let title = localized("paywall.error.title")
        switch error as? PaywallError {
        case .paymentsNotAllowed:
            return Alert(
                title: localized("paywall.payments.unavailable.title"),
                message: localized("paywall.payments.unavailable.message"))
        case .pending:
            return Alert(
                title: localized("paywall.error.pending.title"),
                message: localized("paywall.error.pending"))
        case .productNotFound:
            return Alert(title: title, message: localized("paywall.error.productNotFound"))
        case .verificationFailed:
            return Alert(title: title, message: localized("paywall.error.verificationFailed"))
        case .notActivated:
            return Alert(title: title, message: localized("paywall.error.entitlementNotActive"))
        case .cancelled, .failed, nil:
            return Alert(title: title, message: localized("paywall.error.generic"))
        }
    }
}
#endif
