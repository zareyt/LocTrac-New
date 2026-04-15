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
        case "1.5":
            return [
                WhatsNewFeature(
                    symbolName: "calendar.badge.clock",
                    symbolColor: .blue,
                    title: "Date-Only Tracking",
                    description: "LocTrac now focuses purely on calendar dates. Time displays removed from events — track which day you were somewhere, not the exact hour."
                ),
                WhatsNewFeature(
                    symbolName: "map.fill",
                    symbolColor: .green,
                    title: "State & Province Support",
                    description: "New state/province field for both locations and events provides more precise location tracking, especially useful for domestic travel."
                ),
                WhatsNewFeature(
                    symbolName: "doc.text.fill",
                    symbolColor: .purple,
                    title: "Enhanced Documentation",
                    description: "Comprehensive developer documentation added, including detailed guidelines for date handling, architecture patterns, and project structure."
                ),
                WhatsNewFeature(
                    symbolName: "clock.fill",
                    symbolColor: .orange,
                    title: "Consistent UTC Handling",
                    description: "All dates now stored and compared in UTC timezone, eliminating date-shifting issues when traveling or changing time zones."
                ),
            ]

        default:
            return []
        }
    }
}
