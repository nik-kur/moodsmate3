import UserNotifications
import FirebaseAuth
import SwiftUI

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var isAuthorized = false
    @Published var settings: NotificationSettings = NotificationSettings.loadFromDefaults()
    
    // Singleton instance
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }
    
    // Check if we're authorized to send notifications
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // Request permission to send notifications
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.scheduleNotifications()
                }
            }
            
            if let error = error {
                print("❌ Notification authorization error: \(error.localizedDescription)")
            }
        }
    }
    
    // Save notification settings and reschedule
    func updateSettings(settings: NotificationSettings) {
        self.settings = settings
        settings.saveToDefaults()
        
        // Reschedule notifications based on new settings
        cancelAllNotifications()
        scheduleNotifications()
    }
    
    // Schedule all enabled notifications
    func scheduleNotifications() {
        guard isAuthorized else { return }
        
        if settings.dailyReminderEnabled {
            scheduleDailyReminder()
        }
        
        if settings.weeklyReviewEnabled {
            scheduleWeeklyReviewReminder()
        }
    }
    
    // Cancel all pending notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Specific Notification Types
    
    // Schedule daily reminder at user's preferred time
    private func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time for your mood check-in"
        content.body = "How are you feeling today? Tap to log your mood in just 30 seconds."
        content.sound = .default
        content.categoryIdentifier = "DAILY_REMINDER"
        
        // Get user's preferred time
        let reminderHour = settings.dailyReminderHour
        let reminderMinute = settings.dailyReminderMinute
        
        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling daily reminder: \(error.localizedDescription)")
            }
        }
    }
    
    // Schedule weekly review reminder (Sunday evenings)
    private func scheduleWeeklyReviewReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Mood Summary"
        content.body = "Your weekly mood review is ready. See your patterns and insights!"
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_REVIEW"
        
        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 18     // 6 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weeklyReview", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling weekly review: \(error.localizedDescription)")
            }
        }
    }
    
    // Send a pattern insight notification (called from MoodTrackerViewModel when patterns detected)
    func sendPatternInsight(insight: String) {
        guard isAuthorized && settings.patternInsightsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Mood Pattern Discovered"
        content.body = insight
        content.sound = .default
        content.categoryIdentifier = "PATTERN_INSIGHT"
        
        // Send in 10 seconds (for testing) - in production would be sent immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "patternInsight-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending pattern insight: \(error.localizedDescription)")
            }
        }
    }
    
    // Send re-engagement notification after inactivity
    func sendReengagementNotification(daysInactive: Int) {
        guard isAuthorized && settings.reengagementEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "We've Missed You!"
        
        if daysInactive <= 10 {
            content.body = "It's been \(daysInactive) days since you logged your mood. A quick check-in helps keep your insights accurate."
        } else {
            content.body = "Your mood tracker misses you! Log your mood today to maintain your progress."
        }
        
        content.sound = .default
        content.categoryIdentifier = "REENGAGEMENT"
        
        // Send immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "reengagement-\(daysInactive)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending reengagement: \(error.localizedDescription)")
            }
        }
    }
    
    // Send achievement notification
    func sendAchievementNotification(title: String, description: String) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Achievement Unlocked! 🏆"
        content.body = "\(title): \(description)"
        content.sound = .default
        content.categoryIdentifier = "ACHIEVEMENT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "achievement-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending achievement notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Still show the notification even if app is open
        completionHandler([.banner, .sound])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle different notification types
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        
        switch categoryIdentifier {
        case "DAILY_REMINDER":
            // Could navigate to home/entry view
            print("User tapped daily reminder")
        case "WEEKLY_REVIEW":
            // Could navigate to weekly review
            print("User tapped weekly review")
        case "PATTERN_INSIGHT":
            // Could navigate to analytics
            print("User tapped pattern insight")
        case "REENGAGEMENT":
            // Just open the app
            print("User tapped reengagement")
        case "ACHIEVEMENT":
            // Could navigate to achievements
            print("User tapped achievement")
        default:
            break
        }
        
        completionHandler()
    }
}

// Data model for notification settings
struct NotificationSettings: Codable {
    var dailyReminderEnabled: Bool = true
    var dailyReminderHour: Int = 19  // 7 PM default
    var dailyReminderMinute: Int = 0
    var weeklyReviewEnabled: Bool = true
    var patternInsightsEnabled: Bool = true
    var reengagementEnabled: Bool = true
    
    // Save settings to UserDefaults
    func saveToDefaults() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "notificationSettings")
        }
    }
    
    // Load settings from UserDefaults
    static func loadFromDefaults() -> NotificationSettings {
        if let savedSettings = UserDefaults.standard.data(forKey: "notificationSettings"),
           let decodedSettings = try? JSONDecoder().decode(NotificationSettings.self, from: savedSettings) {
            return decodedSettings
        }
        return NotificationSettings()  // Return default settings if none saved
    }
}
