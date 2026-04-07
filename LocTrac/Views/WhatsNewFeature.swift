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

    // MARK: - Release Definitions

    /// Returns the ordered list of feature pages for a given version string.
    /// Add a new `case` here for each release that deserves a "What's New" screen.
    static func features(for version: String) -> [WhatsNewFeature] {
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

        // ── Add future versions below ──────────────────────────────────────
        // case "1.4":
        //     return [ ... ]

        default:
            return []
        }
    }
}
