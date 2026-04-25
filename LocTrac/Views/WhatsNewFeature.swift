//
//  WhatsNewFeature.swift
//  LocTrac
//
//  Data model for individual "What's New" feature pages shown on first launch
//  of a new version.
//
//  To add pages for a future release, add a new case to the switch below.
//

import SwiftUI

/// Represents a single feature highlight page in the "What's New" sheet.
struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let symbolName: String          // SF Symbol name
    let symbolColor: Color          // Tint for the symbol
    let title: String               // Short feature title
    let description: String         // One or two sentence description
    
    /// Result containing both features and bug fixes
    struct ContentResult {
        let features: [WhatsNewFeature]
        let bugFixes: [WhatsNewFeature]
    }

    // MARK: - Release Definitions
    
    /// Returns features and bug fixes separately for a given version.
    /// First attempts to parse from VERSION_x.x_RELEASE_NOTES.md file.
    /// Falls back to hardcoded features if parsing fails or file doesn't exist.
    static func content(for version: String) -> ContentResult {
        // 🆕 Try dynamic parsing first
        if let parseResult = ReleaseNotesParser.parse(forVersion: version) {
            #if DEBUG
            print("📝 [Parser] Using dynamically parsed content for version \(version)")
            print("📝 [Parser] \(parseResult.features.count) features, \(parseResult.bugFixes.count) bug fixes")
            #endif
            return ContentResult(features: parseResult.features, bugFixes: parseResult.bugFixes)
        }
        
        // 🔄 Fall back to hardcoded features (no bugs in hardcoded)
        #if DEBUG
        print("📝 [Parser] Falling back to hardcoded features for version \(version)")
        #endif
        return ContentResult(features: hardcodedFeatures(for: version), bugFixes: [])
    }

    /// Returns the ordered list of feature pages for a given version string (legacy method).
    /// First attempts to parse from VERSION_x.x_RELEASE_NOTES.md file.
    /// Falls back to hardcoded features if parsing fails or file doesn't exist.
    static func features(for version: String) -> [WhatsNewFeature] {
        // 🆕 Try dynamic parsing first
        if let parsedFeatures = ReleaseNotesParser.parseFeatures(forVersion: version) {
            #if DEBUG
            print("📝 [Parser] Using dynamically parsed features for version \(version)")
            #endif
            return parsedFeatures
        }
        
        // 🔄 Fall back to hardcoded features
        #if DEBUG
        print("📝 [Parser] Falling back to hardcoded features for version \(version)")
        #endif
        return hardcodedFeatures(for: version)
    }
    
    /// Hardcoded fallback features (original implementation).
    /// Kept for backward compatibility and as safety net.
    private static func hardcodedFeatures(for version: String) -> [WhatsNewFeature] {
        switch version {

        case "1.3":
            return [
                WhatsNewFeature(
                    symbolName: "quote.bubble.fill",
                    symbolColor: .purple,
                    title: "Affirmations",
                    description: "Add personal affirmations to any stay. Browse by category, set your favourites, and let LocTrac remind you what matters most."
                ),
                WhatsNewFeature(
                    symbolName: "square.and.arrow.down.fill",
                    symbolColor: .blue,
                    title: "Smarter Imports",
                    description: "Import from backup files with a new timeline slider to cherry-pick exactly the date range you need — including people, activities and trips."
                ),
                WhatsNewFeature(
                    symbolName: "calendar.badge.checkmark",
                    symbolColor: .green,
                    title: "Calendar Refresh Fix",
                    description: "Switching between People, Activities and Locations on the Calendar now refreshes instantly when you change month."
                ),
                WhatsNewFeature(
                    symbolName: "mappin.and.ellipse",
                    symbolColor: .orange,
                    title: "Auto 'Other' Location",
                    description: "The required 'Other' location is created automatically on first setup so non-stay events always have a home."
                ),
            ]

        case "1.4":
            return [
                WhatsNewFeature(
                    symbolName: "airplane.departure",
                    symbolColor: .blue,
                    title: "Travel History",
                    description: "Explore all your stays organized by country and city. Search, filter, and sort to find exactly where you've been — replacing the old 'Other Cities' view with a richer experience."
                ),
                WhatsNewFeature(
                    symbolName: "map.fill",
                    symbolColor: .green,
                    title: "Unified Locations Tab",
                    description: "Map and list views combined into one seamless experience. The new Locations tab automatically refreshes as your travels grow."
                ),
                WhatsNewFeature(
                    symbolName: "chart.bar.doc.horizontal.fill",
                    symbolColor: .purple,
                    title: "Infographics Tab",
                    description: "New dedicated tab for visual insights with full-year and multi-year infographic data. See your travel patterns at a glance with smart US state detection."
                ),
                WhatsNewFeature(
                    symbolName: "sparkles",
                    symbolColor: .orange,
                    title: "First Launch Wizard",
                    description: "New users get a helpful step-by-step onboarding experience to set up LocTrac and start tracking their travels right away."
                ),
                WhatsNewFeature(
                    symbolName: "location.fill.viewfinder",
                    symbolColor: .red,
                    title: "Default Location & Better Management",
                    description: "Set a default location with a ⭐ badge. Enhanced locations manager with search, sorting, mini map previews, and inline editing."
                ),
                WhatsNewFeature(
                    symbolName: "doc.text.fill",
                    symbolColor: .cyan,
                    title: "Improved Documentation",
                    description: "README, Changelog, and License files now display with beautiful markdown formatting — making them easier to read right in the app."
                ),
                WhatsNewFeature(
                    symbolName: "paintpalette.fill",
                    symbolColor: .pink,
                    title: "Custom Location Colors",
                    description: "Pick any color from the full spectrum for your locations — no more theme snapping! Custom colors appear everywhere: lists, maps, pins, and charts."
                ),
                WhatsNewFeature(
                    symbolName: "sparkles.rectangle.stack.fill",
                    symbolColor: .purple,
                    title: "Daily Affirmation Widget",
                    description: "Add the new home screen widget to start each day with a calming affirmation. Updates automatically at midnight with a fresh message."
                ),
                WhatsNewFeature(
                    symbolName: "bell.badge.fill",
                    symbolColor: .red,
                    title: "Daily Notifications",
                    description: "Opt-in to receive a daily notification with your affirmation and a gentle reminder to catch up on missing stays. Sent once per day at your chosen time."
                ),
            ]

        // ── Add future versions below ──────────────────────────────────────
        case "2.0":
            return [
                WhatsNewFeature(
                    symbolName: "person.badge.key.fill",
                    symbolColor: .blue,
                    title: "Sign In with Apple",
                    description: "Securely sign in with your Apple ID. Your credentials are stored safely in the Keychain — no passwords to remember."
                ),
                WhatsNewFeature(
                    symbolName: "envelope.badge.shield.half.filled.fill",
                    symbolColor: .green,
                    title: "Email & Password Accounts",
                    description: "Create a local account with email and password. All authentication stays on your device — no servers, no cloud, fully private."
                ),
                WhatsNewFeature(
                    symbolName: "person.crop.circle.fill",
                    symbolColor: .purple,
                    title: "Profile & Preferences",
                    description: "New profile hub with customizable preferences — set your default location, choose miles or kilometers, and pick a default transport mode."
                ),
                WhatsNewFeature(
                    symbolName: "faceid",
                    symbolColor: .orange,
                    title: "Face ID & Touch ID",
                    description: "Enable biometric unlock for quick, secure access to your travel data. Optional convenience feature you can enable in Security Settings."
                ),
                WhatsNewFeature(
                    symbolName: "lock.shield.fill",
                    symbolColor: .red,
                    title: "Two-Factor Authentication",
                    description: "Add an extra layer of security with TOTP-based two-factor authentication. Works with any authenticator app and includes backup codes."
                ),
                WhatsNewFeature(
                    symbolName: "paintbrush.fill",
                    symbolColor: .red,
                    title: "Event Type Visual Revamp",
                    description: "Event types now use SF Symbol icons and a consistent color palette across the entire app — charts, forms, calendar, maps, and location rows."
                ),
                WhatsNewFeature(
                    symbolName: "tag.fill",
                    symbolColor: .indigo,
                    title: "Custom Event Types",
                    description: "Create, edit, and delete custom event types with your own name, icon, and color. Set a default event type in Preferences to pre-fill new stay forms."
                ),
                WhatsNewFeature(
                    symbolName: "calendar.badge.exclamationmark",
                    symbolColor: .orange,
                    title: "One Stay Per Day",
                    description: "Batch event creation now prevents duplicate stays on the same date. Existing dates are automatically skipped with a summary alert."
                ),
                WhatsNewFeature(
                    symbolName: "brain.head.profile",
                    symbolColor: .blue,
                    title: "Smart Add Stay Button",
                    description: "The Home screen button now adapts to your timeline. It adds today's stay, fills the most recent gap, or lets you edit today's event when you're all caught up."
                ),
                WhatsNewFeature(
                    symbolName: "doc.on.doc.fill",
                    symbolColor: .teal,
                    title: "Copy Stay to Dates",
                    description: "Copy a stay's data to a range of dates. Choose which fields to copy — same-location dates merge automatically, while different-location conflicts let you skip or replace."
                ),
                WhatsNewFeature(
                    symbolName: "figure.walk",
                    symbolColor: .green,
                    title: "Compact Activity Picker",
                    description: "Activities now use a compact chip-based design. Selected activities appear as small tags, and a picker sheet lets you browse and select from all available activities."
                ),
                WhatsNewFeature(
                    symbolName: "camera.fill",
                    symbolColor: .cyan,
                    title: "Event Photos",
                    description: "Add up to 6 photos to any individual stay. Photos are separate from location images — capture moments and activities for specific dates."
                ),
                WhatsNewFeature(
                    symbolName: "archivebox.fill",
                    symbolColor: .purple,
                    title: "Photo Backup & Import",
                    description: "Export photos alongside your data in a .zip archive. Import detects format automatically with conflict resolution — skip, replace, or rename existing photos."
                ),
                WhatsNewFeature(
                    symbolName: "arrow.triangle.2.circlepath",
                    symbolColor: .teal,
                    title: "Seamless Migration",
                    description: "Existing users keep all their data — no migration needed. Optionally create an account to secure your data and prepare for future cloud sync."
                ),
                WhatsNewFeature(
                    symbolName: "mappin.and.ellipse",
                    symbolColor: .teal,
                    title: "Smarter \"Other\" Location Display",
                    description: "Trips and data enhancement views now show the actual city name instead of \"Other\" for events at non-standard locations."
                ),
                WhatsNewFeature(
                    symbolName: "point.topleft.down.to.point.bottomright.curvepath.fill",
                    symbolColor: .blue,
                    title: "Smarter Trip Generation",
                    description: "Fixed trip refresh generating phantom trips between \"Other\" location events in the same city. Trip refresh now shows full details for each addition, modification, and deletion."
                ),
                WhatsNewFeature(
                    symbolName: "bell.badge.clock.fill",
                    symbolColor: .orange,
                    title: "Stay Reminder Timezone Fix",
                    description: "Fixed stay reminder notification incorrectly reporting missing stays due to timezone mismatch. The missing-days count now refreshes on every app launch and event change."
                ),
            ]

        default:
            return []
        }
    }
}
