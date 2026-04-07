//
//  AppVersionManager.swift
//  LocTrac
//
//  Tracks the app version across launches and determines whether to show
//  the "What's New" onboarding sheet for the current release.
//

import Foundation

/// Manages version-based first-launch logic.
/// Store the version string in UserDefaults so we can compare on every launch.
struct AppVersionManager {

    // MARK: - UserDefaults Keys

    private static let lastSeenVersionKey = "LocTrac_lastSeenVersion"

    // MARK: - Current Version

    /// The current marketing version string from the main bundle (e.g. "1.3").
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// The build number string from the main bundle (e.g. "42").
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Seen Version

    /// The version the user last saw a "What's New" sheet for.
    static var lastSeenVersion: String? {
        get { UserDefaults.standard.string(forKey: lastSeenVersionKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastSeenVersionKey) }
    }

    // MARK: - Logic

    /// Returns `true` when the current version has never been acknowledged by the user.
    static var shouldShowWhatsNew: Bool {
        guard let seen = lastSeenVersion else {
            // Never shown anything — only show if there is content defined
            return !WhatsNewFeature.features(for: currentVersion).isEmpty
        }
        // Show when the version string has changed and there is content to show
        return seen != currentVersion && !WhatsNewFeature.features(for: currentVersion).isEmpty
    }

    /// Call this after the "What's New" sheet has been dismissed so it won't appear again
    /// for this version.
    static func markCurrentVersionSeen() {
        lastSeenVersion = currentVersion
    }
}
