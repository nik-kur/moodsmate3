import SwiftUI
import FirebaseAuth

struct MainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MoodTrackerViewModel()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var storeManager = StoreManager()
    @State private var appReady = false
    
    var body: some View {
        if !networkMonitor.isConnected {
            OfflineView()
        } else {
            ZStack {  // Outer ZStack for tutorial overlay
                NavigationView {
                    ZStack {  // Inner ZStack for content and achievement notifications
                        TabView {
                            HomeView()
                                .tabItem {
                                    Label("Home", systemImage: "house.fill")
                                }
                                
                            
                            CalendarView()
                                .tabItem {
                                    Label("Calendar", systemImage: "calendar")
                                }
                               
                            
                            AnalyticsView()
                                .tabItem {
                                    Label("Analytics", systemImage: "chart.bar.fill")
                                }
                                
                            
                            AchievementsView()
                                .tabItem {
                                    Label("Achievements", systemImage: "trophy.fill")
                                }
                               
                            
                            ProfileView()
                                .tabItem {
                                    Label("Profile", systemImage: "person.circle")
                                }
                                
                        }
                       
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Add this
                        .edgesIgnoringSafeArea(.all)
                        .environmentObject(viewModel)
                        .onReceive(viewModel.$moodEntries) { entries in
                            print("MoodEntries updated: \(entries.count) entries")
                            viewModel.checkWeeklyReview()
                        }
                        .onAppear {
                            // Force a fresh load of data when app appears
                            if Auth.auth().currentUser != nil {
                                viewModel.fetchMoodEntries()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                            appReady = true
                                                            PushNotificationHandler.shared.appDidFinishInitializing()
                                                        }
                        }
                       
                        
                        // Achievement Notification Overlay
                        VStack {
                            if viewModel.showingAchievementNotification,
                               let achievement = viewModel.lastUnlockedAchievement {
                                AchievementNotification(
                                    achievement: achievement,
                                    isPresented: $viewModel.showingAchievementNotification
                                )
                                .transition(.move(edge: .top))
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.showingAchievementNotification)
                                .padding(.top, getSafeAreaInsets().top)
                            }
                            Spacer()
                        }
                        .ignoresSafeArea()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Add this line
                }
                .navigationViewStyle(StackNavigationViewStyle()) // Add this line - important for iPad!
                .fixIPadLayout() // Add this line - applies our custom modifier
                .sheet(isPresented: $viewModel.showWeeklyReview) {
                                    if let review = viewModel.currentWeeklyReview,
                                       viewModel.weeklyReviewManager.isWeeklyReviewValid(review) {
                                        WeeklyReviewView(review: review, isPresented: $viewModel.showWeeklyReview)
                                            .environmentObject(viewModel)  // Add this line
                                            .onDisappear {
                                                // Clear any pending weekly review flags upon successful display
                                                UserDefaults.standard.set(false, forKey: "pendingWeeklyReview")
                                            }
                                    } else {
                                        // Show the SafeLoadingView instead of inline loading view
                                        SafeLoadingView(viewModel: viewModel)
                                    }
                                }
                
            }
            
        }
    }
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else {
            return .zero
        }
        return window.safeAreaInsets
    }
    func isWeeklyReviewReadyToDisplay(_ review: WeeklyReview) -> Bool {
        guard review.weekStartDate < review.weekEndDate,
              review.moodSummary.averageMood >= 0,
              review.moodSummary.highestMood >= 0,
              review.moodSummary.lowestMood >= 0 else {
            return false
        }
        // Additional validation as needed
        return true
    }
}

struct SafeLoadingView: View {
    @ObservedObject var viewModel: MoodTrackerViewModel
    @State private var loadAttempts = 0
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255)
    )
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Preparing your weekly mood summary...")
                .font(.headline)
                .foregroundColor(colors.secondary)
            
            Text("This may take a moment")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Add a cancel button after a few seconds
            if loadAttempts > 1 {
                Button("Cancel") {
                    viewModel.showWeeklyReview = false
                }
                .padding()
                .foregroundColor(colors.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
        .onAppear {
            attemptToLoadReview()
        }
    }
    
    private func attemptToLoadReview() {
        loadAttempts += 1
        
        // Try to load/refresh the review data
        viewModel.weeklyReviewManager.fetchSavedReviews()
        
        // Check if review is ready after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let review = viewModel.currentWeeklyReview,
               viewModel.weeklyReviewManager.isWeeklyReviewValid(review) {
                // Review is valid - will stay in the sheet and show the actual review
            } else if loadAttempts < 3 {
                // Try again
                attemptToLoadReview()
            } else {
                // Give up after 3 attempts
                viewModel.showWeeklyReview = false
            }
        }
    }
}
// Add this to any global utility file or at the top of your MainView.swift file
extension UserDefaults {
    static var isDebugModeEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "debug_mode_enabled")
    }
    
    static func toggleDebugMode() {
        let currentValue = UserDefaults.standard.bool(forKey: "debug_mode_enabled")
        UserDefaults.standard.set(!currentValue, forKey: "debug_mode_enabled")
    }
}
