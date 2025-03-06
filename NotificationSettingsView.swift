import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingTimePicker = false
    @State private var tempHour = 19
    @State private var tempMinute = 0
    @Environment(\.presentationMode) var presentationMode
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255)
    )
    
    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notifications")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Stay on track with helpful reminders")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "bell.fill")
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
                    
                    VStack(spacing: 20) {
                        // Main toggle for all notifications
                        
                        // Request permission if not authorized
                        if !notificationManager.isAuthorized {
                            VStack(spacing: 12) {
                                Button(action: {
                                    notificationManager.requestAuthorization()
                                }) {
                                    Text("Enable Notifications")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(colors.secondary)
                                        .cornerRadius(16)
                                }
                                
                                Text("Allow notifications to receive reminders and updates about your mood tracking.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Individual notification settings
                        VStack(spacing: 8) {
                            // Daily Reminder
                            NotificationSetting(
                                title: "Daily Reminder",
                                description: "Get a reminder to log your mood each day",
                                icon: "clock.fill",
                                isOn: $notificationManager.settings.dailyReminderEnabled,
                                action: updateSettings
                            )
                            
                            // Time picker for daily reminder (if enabled)
                            if notificationManager.settings.dailyReminderEnabled {
                                Button(action: {
                                    tempHour = notificationManager.settings.dailyReminderHour
                                    tempMinute = notificationManager.settings.dailyReminderMinute
                                    showingTimePicker = true
                                }) {
                                    HStack {
                                        Text("Reminder Time")
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Text(formattedTime(hour: notificationManager.settings.dailyReminderHour, minute: notificationManager.settings.dailyReminderMinute))
                                            .foregroundColor(colors.secondary)
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Color.secondary)
                                            .font(.system(size: 14))
                                    }
                                    .padding()
                                    .background(colors.buttonBackground)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Weekly Review
                            NotificationSetting(
                                title: "Weekly Review",
                                description: "Get notified when your weekly mood summary is ready (Sundays)",
                                icon: "calendar.badge.clock",
                                isOn: $notificationManager.settings.weeklyReviewEnabled,
                                action: updateSettings
                            )
                            
                            // Removed Pattern Insights and Re-engagement sections
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            TimePickerView(
                hour: $tempHour,
                minute: $tempMinute,
                colors: colors,
                onSave: {
                    var updatedSettings = notificationManager.settings
                    updatedSettings.dailyReminderHour = tempHour
                    updatedSettings.dailyReminderMinute = tempMinute
                    notificationManager.updateSettings(settings: updatedSettings)
                    showingTimePicker = false
                },
                onCancel: {
                    showingTimePicker = false
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(colors.secondary)
                }
            }
        }
    }
    
    private func updateSettings() {
        notificationManager.updateSettings(settings: notificationManager.settings)
    }
    
    private func formattedTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        
        return "\(hour):\(minute)"
    }
    
    private func getSafeAreaTop() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}

// MARK: - Time Picker View

struct TimePickerView: View {
    @Binding var hour: Int
    @Binding var minute: Int
    let colors: (background: Color, secondary: Color, buttonBackground: Color)
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "",
                    selection: Binding(
                        get: {
                            var components = DateComponents()
                            components.hour = hour
                            components.minute = minute
                            return Calendar.current.date(from: components) ?? Date()
                        },
                        set: { newDate in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            hour = components.hour ?? 19
                            minute = components.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Select Time")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(colors.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .foregroundColor(colors.secondary)
                        .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Individual Notification Setting Row

struct NotificationSetting: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    let action: () -> Void
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255)
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(colors.secondary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .foregroundColor(colors.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .onChange(of: isOn) { _, _ in
                        action()
                    }
                    .toggleStyle(SwitchToggleStyle(tint: colors.secondary))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
