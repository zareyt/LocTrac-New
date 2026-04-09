//
//  NotificationManager.swift
//  LocTrac
//
//  Manages daily notifications for affirmations and stay reminders
//  Notifications sent once per day between 12:00 AM - 12:00 PM
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isNotificationsEnabled: Bool = false
    @Published var notificationTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date() // Default 9:00 AM
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    // Notification identifiers
    private let dailyAffirmationID = "com.loctrac.dailyAffirmation"
    private let stayReminderID = "com.loctrac.stayReminder"
    
    // UserDefaults keys
    private let notificationsEnabledKey = "notificationsEnabled"
    private let notificationTimeKey = "notificationTime"
    
    private init() {
        loadSettings()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                self.isNotificationsEnabled = granted
                self.saveSettings()
            }
            await checkAuthorizationStatus()
            
            if granted {
                await scheduleNotifications()
            }
            
            return granted
        } catch {
            print("❌ Notification authorization error: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.authorizationStatus = settings.authorizationStatus
                
                // Update enabled state based on system authorization
                if settings.authorizationStatus == .denied || settings.authorizationStatus == .notDetermined {
                    self.isNotificationsEnabled = false
                    self.saveSettings()
                }
            }
        }
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleNotifications() async {
        guard isNotificationsEnabled else {
            await cancelAllNotifications()
            return
        }
        
        // Cancel existing notifications
        await cancelAllNotifications()
        
        // Schedule daily affirmation
        await scheduleDailyAffirmation()
        
        print("✅ Notifications scheduled for \(formatTime(notificationTime))")
    }
    
    private func scheduleDailyAffirmation() async {
        let content = UNMutableNotificationContent()
        
        // Get today's affirmation (same as widget)
        let affirmation = getTodaysAffirmation()
        
        content.title = "Daily Affirmation"
        content.body = affirmation.text
        content.sound = UNNotificationSound(named: UNNotificationSoundName("calm_notification.aiff"))
        content.categoryIdentifier = "AFFIRMATION"
        content.badge = 0
        
        // Add action buttons
        content.userInfo = [
            "type": "affirmation",
            "affirmationID": affirmation.id,
            "category": affirmation.category.rawValue
        ]
        
        // Schedule notification time (respects user's chosen time)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: notificationTime)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: dailyAffirmationID,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Daily affirmation notification scheduled for \(components.hour ?? 9):\(String(format: "%02d", components.minute ?? 0))")
        } catch {
            print("❌ Failed to schedule affirmation: \(error)")
        }
    }
    
    func scheduleStayReminder(for store: DataStore) async {
        guard isNotificationsEnabled else { return }
        
        // Check if user has a stay for today
        let today = Calendar.current.startOfDay(for: Date())
        let hasStayToday = store.events.contains { event in
            Calendar.current.isDate(event.date, inSameDayAs: today)
        }
        
        // Check for missing stays in the past 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        let daysWithStays = Set(store.events.compactMap { event -> Date? in
            let eventDay = Calendar.current.startOfDay(for: event.date)
            guard eventDay >= sevenDaysAgo && eventDay <= today else { return nil }
            return eventDay
        })
        
        var missingDaysCount = 0
        var currentDate = sevenDaysAgo
        while currentDate <= today {
            if !daysWithStays.contains(currentDate) {
                missingDaysCount += 1
            }
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Only send reminder if there are missing stays
        guard missingDaysCount > 0 else {
            // Cancel stay reminder if no missing days
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [stayReminderID])
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Catch Up on Your Travel Log"
        
        if !hasStayToday {
            content.body = "Don't forget to log today's stay and \(missingDaysCount) other recent day\(missingDaysCount > 1 ? "s" : "")."
        } else {
            content.body = "You have \(missingDaysCount) day\(missingDaysCount > 1 ? "s" : "") without logged stays in the past week."
        }
        
        content.sound = UNNotificationSound(named: UNNotificationSoundName("calm_notification.aiff"))
        content.categoryIdentifier = "STAY_REMINDER"
        content.badge = NSNumber(value: missingDaysCount)
        content.userInfo = [
            "type": "stayReminder",
            "missingDaysCount": missingDaysCount,
            "hasStayToday": hasStayToday
        ]
        
        // Schedule for 15 minutes after the affirmation
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: notificationTime)
        components.minute = (components.minute ?? 0) + 15
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: stayReminderID,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Stay reminder scheduled with \(missingDaysCount) missing days")
        } catch {
            print("❌ Failed to schedule stay reminder: \(error)")
        }
    }
    
    func cancelAllNotifications() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🗑️ All notifications cancelled")
    }
    
    // MARK: - Affirmation Logic (same as widget)
    
    private func getTodaysAffirmation() -> Affirmation {
        // Use same logic as widget for consistency
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let affirmations = Affirmation.presets
        let index = (dayOfYear - 1) % affirmations.count
        return affirmations[index]
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        isNotificationsEnabled = UserDefaults.standard.bool(forKey: notificationsEnabledKey)
        
        if let timeInterval = UserDefaults.standard.object(forKey: notificationTimeKey) as? TimeInterval {
            notificationTime = Date(timeIntervalSince1970: timeInterval)
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isNotificationsEnabled, forKey: notificationsEnabledKey)
        UserDefaults.standard.set(notificationTime.timeIntervalSince1970, forKey: notificationTimeKey)
    }
    
    func updateNotificationTime(_ newTime: Date) async {
        notificationTime = newTime
        saveSettings()
        
        if isNotificationsEnabled {
            await scheduleNotifications()
        }
    }
    
    func toggleNotifications(enabled: Bool, store: DataStore? = nil) async {
        if enabled && authorizationStatus != .authorized {
            let granted = await requestAuthorization()
            if !granted { return }
        }
        
        isNotificationsEnabled = enabled
        saveSettings()
        
        if enabled {
            await scheduleNotifications()
            if let store = store {
                await scheduleStayReminder(for: store)
            }
        } else {
            await cancelAllNotifications()
        }
    }
    
    // MARK: - Notification Actions
    
    func registerNotificationCategories() {
        // Define actions for affirmation notifications
        let viewAction = UNNotificationAction(
            identifier: "VIEW_AFFIRMATION",
            title: "View in App",
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )
        
        let affirmationCategory = UNNotificationCategory(
            identifier: "AFFIRMATION",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Define actions for stay reminders
        let addStayAction = UNNotificationAction(
            identifier: "ADD_STAY",
            title: "Add Stay",
            options: .foreground
        )
        
        let stayReminderCategory = UNNotificationCategory(
            identifier: "STAY_REMINDER",
            actions: [addStayAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            affirmationCategory,
            stayReminderCategory
        ])
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
}

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @EnvironmentObject var store: DataStore
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationStack {
            Form {
                // Notifications Toggle Section
                Section {
                    Toggle(isOn: Binding(
                        get: { notificationManager.isNotificationsEnabled },
                        set: { newValue in
                            Task {
                                await notificationManager.toggleNotifications(enabled: newValue, store: store)
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Notifications")
                                .font(.headline)
                            Text("Affirmation + Stay Reminder")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Notifications", systemImage: "bell.fill")
                } footer: {
                    Text("Receive a daily affirmation and reminder to log your stays. Sent once per day between 12:00 AM and 12:00 PM.")
                }
                
                // Time Picker Section
                if notificationManager.isNotificationsEnabled {
                    Section {
                        DatePicker(
                            "Notification Time",
                            selection: Binding(
                                get: { notificationManager.notificationTime },
                                set: { newTime in
                                    Task {
                                        await notificationManager.updateNotificationTime(newTime)
                                    }
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    } header: {
                        Label("Schedule", systemImage: "clock.fill")
                    } footer: {
                        Text("Choose when you'd like to receive your daily notification. Recommended: morning hours for best effectiveness.")
                    }
                }
                
                // System Settings Section
                if notificationManager.authorizationStatus == .denied {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Notifications Disabled", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.headline)
                            
                            Text("Notifications are disabled in your device settings. To enable them:")
                                .font(.subheadline)
                            
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            } label: {
                                Label("Open Settings", systemImage: "gear")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Preview Section
                if notificationManager.isNotificationsEnabled {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("What You'll Receive", systemImage: "sparkles")
                                .font(.headline)
                            
                            // Affirmation Preview
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "quote.bubble.fill")
                                        .foregroundColor(.purple)
                                    Text("Daily Affirmation")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                Text("Displays the same affirmation as your home screen widget")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                            
                            // Stay Reminder Preview
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .foregroundColor(.blue)
                                    Text("Stay Reminder")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                Text("Reminds you to catch up on any missing stays from recent days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    } header: {
                        Label("Preview", systemImage: "eye.fill")
                    }
                }
                
                // Info Section
                Section {
                    InfoRow(icon: "moon.fill", text: "Calm, supportive tone", color: .indigo)
                    InfoRow(icon: "checkmark.circle.fill", text: "Sent once per day", color: .green)
                    InfoRow(icon: "clock.fill", text: "Morning delivery (12 AM - 12 PM)", color: .orange)
                    InfoRow(icon: "lock.fill", text: "Respects Do Not Disturb", color: .gray)
                } header: {
                    Label("Features", systemImage: "star.fill")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Helper view for info rows
private struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
            .environmentObject(DataStore())
    }
}
