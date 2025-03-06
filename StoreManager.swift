import StoreKit

@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []

    func loadProducts() async {
        do {
            let productIds: Set<String> = ["com.yourapp.subscription.monthly", "com.yourapp.subscription.yearly"]
            let fetchedProducts = try await Product.products(for: productIds)
            
            DispatchQueue.main.async {
                self.products = fetchedProducts
            }
        } catch {
            print("❌ Error loading products: \(error.localizedDescription)")
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    print("✅ Purchase successful: \(transaction.productID)")
                    DispatchQueue.main.async {
                        self.purchasedSubscriptions.append(product)
                    }
                    await transaction.finish()
                case .unverified(let transaction, let error):
                    print("❌ Unverified transaction: \(error.localizedDescription)")
                    print("Transaction details: \(transaction)")
                }
            case .pending:
                print("⏳ Purchase pending")
            case .userCancelled:
                print("❌ User cancelled purchase")
            @unknown default:
                print("❌ Unknown purchase state")
            }
        } catch {
            print("❌ Purchase failed: \(error.localizedDescription)")
        }
    }

    // Restore purchases method
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            print("✅ Purchases restored successfully")
            
            // Verify and update purchased subscriptions
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    if let product = products.first(where: { $0.id == transaction.productID }) {
                        DispatchQueue.main.async {
                            if !self.purchasedSubscriptions.contains(product) {
                                self.purchasedSubscriptions.append(product)
                            }
                        }
                    }
                case .unverified(_, let error):
                    print("❌ Unverified transaction during restore: \(error.localizedDescription)")
                }
            }
        } catch {
            print("❌ Error restoring purchases: \(error.localizedDescription)")
        }
    }
}
