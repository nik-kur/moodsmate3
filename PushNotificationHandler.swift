// Fix for PushNotificationHandler.swift

import UIKit
import SwiftUI

class PushNotificationHandler {
    static let shared = PushNotificationHandler()
    
    // State tracking
    private var appLaunchedFromNotification = false
    private var pendingWeeklyReviewNotification = false
    private var appInitializationComplete = false
    private var retryCount = 0
    private let maxRetries = 3
    
    // MARK: - Configuration Functions
    
    /// Call this from your AppDelegate when a notification launches the app
    func handleAppLaunchFromNotification(userInfo: [AnyHashable: Any]) {
        appLaunchedFromNotification = true
        
        // Check if it's a weekly review notification
        if isWeeklyReviewNotification(userInfo) {
            print("📱 App launched from weekly review notification")
            pendingWeeklyReviewNotification = true
            
            // Reset the retry counter
            retryCount = 0
            
            // Store that we have a pending weekly review to show
            UserDefaults.standard.set(true, forKey: "pendingWeeklyReview")
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Call this from your main view when the app is fully loaded and ready
    func appDidFinishInitializing() {
        appInitializationComplete = true
        
        // If we have a pending weekly review to handle, do it now
        if pendingWeeklyReviewNotification {
            processPendingWeeklyReviewWithDelay()
        }
    }
    
    // MARK: - Review Processing Functions
    
    /// Process the pending weekly review notification with a safe delay
    private func processPendingWeeklyReviewWithDelay() {
        // Wait for 2 seconds to ensure the app is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.processPendingWeeklyReview()
        }
    }
    
    /// Safely attempt to process the pending weekly review
    private func processPendingWeeklyReview() {
        // Get reference to the view model
        guard let viewModel = getCurrentMoodTrackerViewModel() else {
            print("⚠️ Cannot access MoodTrackerViewModel, retrying...")
            retryShowingWeeklyReview()
            return
        }
        
        // First, ensure data is refreshed
        print("🔄 Refreshing data before showing weekly review...")
        viewModel.fetchMoodEntries()
        
        // Then attempt to load the review
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Get the weekly review manager
            let reviewManager = viewModel.weeklyReviewManager
            
            // Fetch reviews first
            reviewManager.fetchSavedReviews()
            
            // Wait for fetching to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Get the most recent review
                let reviews = reviewManager.getDisplayableReviews()
                if let latestReview = reviews.first {
                    // Validate the review
                    if reviewManager.isWeeklyReviewValid(latestReview) {
                        print("✅ Weekly review is valid, proceeding to display")
                        
                        // Set the current review and show it
                        viewModel.currentWeeklyReview = latestReview
                        viewModel.showWeeklyReview = true
                        
                        // Clear the pending flag
                        self.pendingWeeklyReviewNotification = false
                        UserDefaults.standard.set(false, forKey: "pendingWeeklyReview")
                    } else {
                        print("⚠️ Weekly review validation failed, retrying...")
                        self.retryShowingWeeklyReview()
                    }
                } else {
                    print("⚠️ No reviews available, retrying...")
                    self.retryShowingWeeklyReview()
                }
            }
        }
    }
    
    /// Retry showing the weekly review if a previous attempt failed
    private func retryShowingWeeklyReview() {
        retryCount += 1
        
        if retryCount <= maxRetries {
            print("🔄 Retry attempt \(retryCount) of \(maxRetries)...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.processPendingWeeklyReview()
            }
        } else {
            print("❌ Max retry attempts reached. Giving up on showing weekly review.")
            // Clear the pending flag after max retries
            pendingWeeklyReviewNotification = false
            UserDefaults.standard.set(false, forKey: "pendingWeeklyReview")
        }
    }
    
    // MARK: - Helper Functions
    
    /// Determine if the notification is for a weekly review
    private func isWeeklyReviewNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        // Check for any identifiers in your notification payload that indicate a weekly review
        if let category = userInfo["category"] as? String, category == "WEEKLY_REVIEW" {
            return true
        }
        
        // Check for custom data that might indicate a weekly review
        if let aps = userInfo["aps"] as? [String: Any],
           let alert = aps["alert"] as? [String: Any],
           let title = alert["title"] as? String,
           title.contains("Weekly") && title.contains("Summary") {
            return true
        }
        
        return false
    }
    
    /// Access the current MoodTrackerViewModel instance from the app
    private func getCurrentMoodTrackerViewModel() -> MoodTrackerViewModel? {
        return MoodTrackerViewModel.shared
    }
    
    /// Attempt to find our view model in a SwiftUI view hierarchy
    private func findViewModelInEnvironment(_ hostingController: UIHostingController<AnyView>) -> MoodTrackerViewModel? {
        // This is a limited implementation that in practice would need a more robust approach
        // In a real app, consider using a singleton or dedicated service for this kind of access
        
        // For now, we'll return nil and recommend implementing a proper singleton pattern for the view model
        return nil
    }
    
    /// Check for pending weekly review on app restart
    func checkForPendingReviewOnLaunch() {
        if UserDefaults.standard.bool(forKey: "pendingWeeklyReview") {
            print("📱 Found pending weekly review from previous session")
            pendingWeeklyReviewNotification = true
            
            // Reset retry counter
            retryCount = 0
            
            // If the app is already initialized, process immediately
            if appInitializationComplete {
                processPendingWeeklyReviewWithDelay()
            }
            // Otherwise, it will be processed when appDidFinishInitializing is called
        }
    }
}
