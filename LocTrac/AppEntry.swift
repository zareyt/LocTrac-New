//
// LocTrac
// by Tim Arey on 2023-02-22
// Using Swift 5.0
//
//
// Based from UICalendar example https://youTube.com/StewartLynch
//

import SwiftUI
import UserNotifications

@main
struct AppEntry: App {
    var store = DataStore()
    
    init() {
        // Register notification categories on app launch
        NotificationManager.shared.registerNotificationCategories()
        print("✅ Notification categories registered")
    }
   
    var body: some Scene {
        WindowGroup {
            StartTabView()
                .environmentObject(store)
                .onAppear {
                    // Check notification authorization status
                    NotificationManager.shared.checkAuthorizationStatus()
                    
                    // Clear badge when app opens
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
        }
    }
}

