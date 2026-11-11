#if os(iOS) || os(macOS)
import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class PaywallModel {
    struct Alert: Equatable {
        var title: PaywallString
        var message: PaywallString
    }

    static let thanksLead: Duration = .milliseconds(320)
    static let thanksDwell: Duration = .milliseconds(3600)
    static let thanksDwellReduced: Duration = .milliseconds(3000)

    @ObservationIgnored let service: any PaywallService
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored private var entitlementObservation: Task<Void, Never>?
    @ObservationIgnored private(set) var celebration: Task<Void, Never>?

    /// The plan the user chose; `selectedPlan` falls back while the service does not offer it.
    private var chosenPlan: PaywallPlan = .yearly
    var isPurchasePending = false
    var isPurchasing = false
    var isRestoring = false
    var didSucceed = false
    var didRestore = false
    /// What the alert shows. It stays after the alert closes, so its text holds while it fades.
    private(set) var alert: Alert?
    var isAlertPresented = false
    var shouldDismiss = false
    var isThanking = false
    /// The first load has not returned, or a retry is running.
    private(set) var isLoading = true
    /// A purchase reported `.paymentsNotAllowed` although the service allowed payments.
    private var paymentsRefused = false

    init(
        service: any PaywallService,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) })
    {
        self.service = service
        self.sleep = sleep
    }

    /// The service's plans in display order. Read from the service on every access, so plans it
    /// already holds are on screen in the first frame and later changes show up.
    var products: [PaywallProduct] {
        let offered = self.service.products
        return PaywallPlan.allCases.compactMap { plan in
            offered.first { $0.plan == plan }
        }
    }

    var canMakePayments: Bool {
        self.service.canMakePayments && !self.paymentsRefused
    }

    /// Yearly first; if the chosen plan is not offered, yearly, then the first plan that is.
    var selectedPlan: PaywallPlan {
        let products = self.products
        return [self.chosenPlan, .yearly].first { plan in products.contains { $0.plan == plan } }
            ?? products.first?.plan
            ?? self.chosenPlan
    }

    var paymentsUnavailable: Bool {
        !self.isLoadingProducts && !self.canMakePayments
    }

    var productsUnavailable: Bool {
        !self.isLoadingProducts && self.canMakePayments && self.products.isEmpty
    }

    var isLoadingProducts: Bool {
        self.isLoading && self.products.isEmpty
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
        self.canPurchase || self.isPurchasing || self.didSucceed || self.isRestoringWithPurchasablePlan
    }

    private var isRestoringWithPurchasablePlan: Bool {
        self.isRestoring
            && self.canMakePayments
            && self.selectedProduct != nil
            && !self.isPurchasePending
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
        guard !self.isLoading else { return }
        self.isLoading = true
        await self.loadProducts(forceRefresh: true)
    }

    func select(_ plan: PaywallPlan) {
        guard self.canMakePayments, !self.isPurchasing, !self.didSucceed,
              self.product(for: plan) != nil else { return }
        self.chosenPlan = plan
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
            self.paymentsRefused = true
        }
        if let alert = Self.alert(for: error) {
            self.present(alert)
        }
    }

    func restoreFinished(_ entitlement: PaywallEntitlement) {
        guard !self.didSucceed else { return }
        self.isRestoring = false
        if entitlement == .entitled {
            self.finishPurchase(restored: true)
        } else {
            self.present(Alert(title: .nothingToRestoreTitle, message: .nothingToRestore))
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
        self.present(Alert(title: .restoreFailedTitle, message: .restoreFailed))
    }

    private func present(_ alert: Alert) {
        self.alert = alert
        self.isAlertPresented = true
    }

    private func loadProducts(forceRefresh: Bool) async {
        await self.service.loadProducts(forceRefresh: forceRefresh)
        self.isLoading = false
    }

    private func observeEntitlement() {
        self.entitlementObservation?.cancel()
        let service = self.service
        var sawFree = service.entitlement == .free
        self.entitlementObservation = Task { [weak self] in
            for await entitlement in Observations({ service.entitlement }) {
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
        self.isAlertPresented = false
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
        switch error as? PaywallError {
        case .paymentsNotAllowed:
            return Alert(title: .paymentsUnavailableTitle, message: .paymentsUnavailableMessage)
        case .pending:
            return Alert(title: .pendingTitle, message: .pending)
        case .productNotFound:
            return Alert(title: .purchaseFailedTitle, message: .productNotFound)
        case .verificationFailed:
            return Alert(title: .purchaseFailedTitle, message: .verificationFailed)
        case .notActivated:
            return Alert(title: .purchaseFailedTitle, message: .notActivated)
        case .cancelled, .failed, nil:
            return Alert(title: .purchaseFailedTitle, message: .purchaseFailed)
        }
    }
}
#endif
