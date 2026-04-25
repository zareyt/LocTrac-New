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
    @StateObject private var store = DataStore()
    @StateObject private var authState = AuthState()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = false

    init() {
        // Register notification categories on app launch
        NotificationManager.shared.registerNotificationCategories()
        print("✅ Notification categories registered")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                StartTabView()
                    .environmentObject(store)
                    .environmentObject(authState)
                    .onAppear {
                        // Check notification authorization status
                        NotificationManager.shared.checkAuthorizationStatus()

                        // Clear badge when app opens
                        UNUserNotificationCenter.current().setBadgeCount(0)

                        // Refresh stay reminder with current data on launch
                        store.updateStayReminders()
                    }

                // Biometric lock overlay
                if isLocked {
                    BiometricLockView(isLocked: $isLocked)
                }
            }
            .environmentObject(DebugConfig.shared)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    if BiometricService.isEnabled && authState.isAuthenticated {
                        isLocked = true
                        #if DEBUG
                        print("🔐 [App] Locked on background")
                        #endif
                    }
                case .active:
                    if isLocked {
                        authenticateWithBiometrics()
                    }
                    // Refresh stay reminder with current data when returning to foreground
                    store.updateStayReminders()
                default:
                    break
                }
            }
        }
    }

    private func authenticateWithBiometrics() {
        Task {
            do {
                let success = try await BiometricService.authenticate(
                    reason: "Unlock LocTrac"
                )
                await MainActor.run {
                    if success {
                        isLocked = false
                        #if DEBUG
                        print("🔐 [App] Unlocked via biometrics")
                        #endif
                    }
                }
            } catch {
                #if DEBUG
                print("🔐 [App] Biometric unlock failed: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

