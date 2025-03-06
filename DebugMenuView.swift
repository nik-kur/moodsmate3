import SwiftUI

struct DebugMenuView: View {
    @ObservedObject var viewModel: MoodTrackerViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var debugActionResult = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Weekly Review Testing")) {
                    Button("Trigger Weekly Review Display") {
                        triggerWeeklyReview()
                    }
                    
                    Button("Simulate Push Notification") {
                        simulatePushNotification()
                    }
                    
                    Button("Simulate App Launch from Notification") {
                        simulateAppLaunch()
                    }
                    
                    Button("Force Generate New Review") {
                        forceGenerateReview()
                    }
                    
                    Button("Test With Corrupted Review") {
                        testCorruptedReview()
                    }
                }
                
                Section(header: Text("Debug Controls")) {
                    // Toggle global debug mode
                    Toggle("Debug Mode Enabled", isOn: Binding(
                        get: { UserDefaults.isDebugModeEnabled },
                        set: { newValue in
                            UserDefaults.standard.set(newValue, forKey: "debug_mode_enabled")
                        }
                    ))
                    
                    Button("Clear All Debug Flags") {
                        clearDebugFlags()
                    }
                    
                    if !debugActionResult.isEmpty {
                        Text(debugActionResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Debug Actions
    
    private func triggerWeeklyReview() {
        debugActionResult = "Triggering weekly review..."
        
        // Fetch reviews first
        viewModel.weeklyReviewManager.fetchSavedReviews()
        
        // Wait for fetch to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let review = viewModel.weeklyReviewManager.getDisplayableReviews().first {
                viewModel.currentWeeklyReview = review
                viewModel.showWeeklyReview = true
                presentationMode.wrappedValue.dismiss()
                debugActionResult = "Weekly review triggered successfully"
            } else {
                debugActionResult = "No reviews available to display"
            }
        }
    }
    
    private func simulatePushNotification() {
        debugActionResult = "Simulating push notification..."
        
        // Create a mock notification payload
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Your Weekly Mood Summary",
                    "body": "Your weekly review is ready!"
                ],
                "sound": "default"
            ],
            "category": "WEEKLY_REVIEW"
        ]
        
        // Simulate handling the notification
        PushNotificationHandler.shared.handleAppLaunchFromNotification(userInfo: userInfo)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func simulateAppLaunch() {
        debugActionResult = "Simulating app launch from notification..."
        
        // Set the pending weekly review flag
        UserDefaults.standard.set(true, forKey: "pendingWeeklyReview")
        
        // Simulate app becoming active
        PushNotificationHandler.shared.checkForPendingReviewOnLaunch()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func forceGenerateReview() {
        debugActionResult = "Generating new weekly review..."
        let entries = viewModel.moodEntries
        
        if entries.isEmpty {
            debugActionResult = "No mood entries found to generate review"
            return
        }
        
        // Force create a review with recent entries
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let startOfLastWeek = calendar.startOfDay(for: weekAgo)
        let endOfLastWeek = calendar.startOfDay(for: now)
        
        // Filter entries from last week
        let weekEntries = entries.filter { entry in
            entry.date >= startOfLastWeek && entry.date < endOfLastWeek
        }
        
        if !weekEntries.isEmpty {
            // Generate and show review
            viewModel.weeklyReviewManager.checkAndGenerateWeeklyReview(entries: entries)
            presentationMode.wrappedValue.dismiss()
            debugActionResult = "Weekly review generated with \(weekEntries.count) entries"
        } else {
            debugActionResult = "No entries found in the last week"
        }
    }
    
    private func testCorruptedReview() {
        debugActionResult = "Testing with corrupted review data..."
        
        // Create an invalid review with problematic data
        let invalidReview = WeeklyReview(
            id: UUID(),
            weekStartDate: Date(), // Invalid: Start date is after end date
            weekEndDate: Date().addingTimeInterval(-86400),
            moodSummary: WeeklyReview.MoodSummary(
                averageMood: -1, // Invalid negative value
                highestMood: 11, // Invalid over 10
                lowestMood: 0,
                mostFrequentFactors: [],
                bestDay: Date()
            ),
            highlights: [],
            photos: [],
            notes: [],
            hasBeenViewed: false
        )
        
        // Try to display it
        viewModel.currentWeeklyReview = invalidReview
        viewModel.showWeeklyReview = true
        presentationMode.wrappedValue.dismiss()
    }
    
    private func clearDebugFlags() {
        UserDefaults.standard.set(false, forKey: "pendingWeeklyReview")
        UserDefaults.standard.set(false, forKey: "debug_mode_enabled")
        debugActionResult = "All debug flags cleared"
    }
}
