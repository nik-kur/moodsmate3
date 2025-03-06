import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var storeManager: MockStoreManager
    @StateObject private var networkMonitor = NetworkMonitor()
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        text: Color.primary,
        textSecondary: Color.secondary
    )
    
    var body: some View {
        if !networkMonitor.isConnected {
            OfflineView()
        } else {
            NavigationView {
                ZStack {
                    colors.background.ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Premium Features")
                                            .font(.system(size: 34, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Choose your plan")
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, getSafeAreaTop())
                            .padding(.bottom, 24)
                            .background(
                                colors.secondary
                                    .cornerRadius(30, corners: [.bottomLeft, .bottomRight])
                            )
                            
                            // Subscription Plans
                            VStack(spacing: 20) {
                                if storeManager.products.isEmpty {
                                    ProgressView("Loading subscriptions...")
                                        .padding(.top, 40)
                                } else {
                                    ForEach(storeManager.products) { product in
                                        EnhancedSubscriptionCard(product: product) {
                                            Task {
                                                await storeManager.purchase(product)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 24)
                        }
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }
    
    private func getSafeAreaTop() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}

struct EnhancedSubscriptionCard: View {
    let product: StoreKitProduct
    let onSubscribe: () -> Void
    
    private let colors = (
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        positiveGreen: Color(red: 126/255, green: 188/255, blue: 137/255)
    )
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(product.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(colors.secondary)
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text(product.displayPrice)
                            .font(.system(size: 28, weight: .bold))
                        
                        Text(getPeriodText(for: product))
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: product.icon)
                    .font(.system(size: 32))
                    .foregroundColor(colors.secondary)
            }
            
            // Discount Badge if available
            if let discount = product.discountInfo {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(colors.positiveGreen)
                    Text(discount)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colors.positiveGreen)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(colors.positiveGreen.opacity(0.15))
                .cornerRadius(12)
            }
            
            // Free Trial Badge
            if let trial = product.freeTrial {
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundColor(colors.secondary)
                    Text(trial)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colors.secondary)
                }
                .padding(.top, 4)
            }
            
            // Subscribe Button
            Button(action: onSubscribe) {
                Text(product.freeTrial != nil ? "Start Free Trial" : "Subscribe Now")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(colors.secondary)
                    .cornerRadius(16)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isPopular(product) ? colors.secondary.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
    
    private func getPeriodText(for product: StoreKitProduct) -> String {
        switch product.displayName.lowercased() {
        case let name where name.contains("monthly"): return "per month"
        case let name where name.contains("3-month"): return "per quarter"
        case let name where name.contains("annual"): return "per year"
        default: return "per period"
        }
    }
    
    private func isPopular(_ product: StoreKitProduct) -> Bool {
        product.displayName.contains("3-Month")
    }
}

// Mock Store Manager (Keep your existing implementation)
class MockStoreManager: ObservableObject {
    @Published var products: [StoreKitProduct] = [
        StoreKitProduct(id: "com.moodmate.subscription.monthly", displayName: "Monthly Plan", displayPrice: "$4.99", freeTrial: "3-day free trial", icon: "calendar", discountInfo: nil),
        StoreKitProduct(id: "com.moodmate.subscription.3months", displayName: "3-Month Plan", displayPrice: "$9.99", freeTrial: "7-day free trial", icon: "star.circle.fill", discountInfo: "Save 17%"),
        StoreKitProduct(id: "com.moodmate.subscription.yearly", displayName: "Annual Plan", displayPrice: "$49.99", freeTrial: "7-day free trial", icon: "crown.fill", discountInfo: "Save 38%")
    ]
    
    func purchase(_ product: StoreKitProduct) async {
        print("Simulated purchase for product: \(product.displayName)")
    }
}

// StoreKit Product Model (Keep your existing implementation)
struct StoreKitProduct: Identifiable {
    let id: String
    let displayName: String
    let displayPrice: String
    let freeTrial: String?
    let icon: String
    let discountInfo: String?
}

#Preview {
    SubscriptionView()
        .environmentObject(MockStoreManager())
}
