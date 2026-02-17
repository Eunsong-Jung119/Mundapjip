//
//  StoreManager.swift
//  Mundapjip
//

import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {

    // MARK: - Product ID
    static let productID = "com.eunsong.mundapjip.permanentOwnership"

    // MARK: - State
    enum PurchaseState: Equatable {
        case idle, purchasing, purchased, failed(String)
    }

    @Published var product: Product?
    @Published var purchaseState: PurchaseState = .idle
    @Published var isPurchased: Bool = false

    private var transactionListener: Task<Void, Never>?

    // MARK: - UserDefaults Cache
    private static let purchasedKey = "store.isPurchased"

    // MARK: - Init / Deinit
    init() {
        isPurchased = UserDefaults.standard.bool(forKey: Self.purchasedKey)
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Product
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            print("❌ [Store] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase
    func purchase() async {
        guard let product else {
            purchaseState = .failed("상품 정보를 불러올 수 없습니다.")
            return
        }

        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    setPurchased(true)
                    purchaseState = .purchased
                } else {
                    purchaseState = .failed("구매 검증에 실패했습니다.")
                }

            case .userCancelled:
                purchaseState = .idle

            case .pending:
                purchaseState = .idle

            @unknown default:
                purchaseState = .failed("알 수 없는 오류가 발생했습니다.")
            }
        } catch {
            purchaseState = .failed("결제 중 오류가 발생했습니다: \(error.localizedDescription)")
        }
    }

    // MARK: - Check Purchase Status
    func checkPurchaseStatus() async {
        guard let result = await Transaction.currentEntitlement(for: Self.productID) else {
            setPurchased(false)
            return
        }

        if case .verified(_) = result {
            setPurchased(true)
        } else {
            setPurchased(false)
        }
    }

    // MARK: - Restore
    var onRestoreSuccess: (() async -> Void)?

    func restore() async {
        do {
            try await AppStore.sync()
            await checkPurchaseStatus()
            if isPurchased {
                purchaseState = .purchased
                await onRestoreSuccess?()
            }
        } catch {
            purchaseState = .failed("복원에 실패했습니다: \(error.localizedDescription)")
        }
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.setPurchased(true)
                }
            }
        }
    }

    // MARK: - Helpers
    private func setPurchased(_ value: Bool) {
        isPurchased = value
        UserDefaults.standard.set(value, forKey: Self.purchasedKey)
    }
}
