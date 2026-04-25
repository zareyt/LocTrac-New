//
//  DebugConfigTests.swift
//  LocTrac
//
//  Tests for the DebugConfig system: categories, presets, log gating, and view modifier.
//

import Testing
import Foundation
@testable import LocTrac

@Suite("DebugConfig Tests")
struct DebugConfigTests {

    // MARK: - LogCategory Properties

    @Test("All log categories have unique emojis")
    func uniqueEmojis() {
        let categories: [LogCategory] = [
            .dataStore, .persistence, .navigation, .network, .cache,
            .trips, .lifecycle, .performance, .charts, .parser,
            .startup, .photos, .calendar, .auth
        ]
        let emojis = categories.map { $0.emoji }
        #expect(Set(emojis).count == categories.count, "Some categories share the same emoji")
    }

    @Test("All log categories have unique labels")
    func uniqueLabels() {
        let categories: [LogCategory] = [
            .dataStore, .persistence, .navigation, .network, .cache,
            .trips, .lifecycle, .performance, .charts, .parser,
            .startup, .photos, .calendar, .auth
        ]
        let labels = categories.map { $0.label }
        #expect(Set(labels).count == categories.count, "Some categories share the same label")
    }

    @Test("Category labels are lowercase alphanumeric")
    func labelsAreLowercase() {
        let categories: [LogCategory] = [
            .dataStore, .persistence, .navigation, .network, .cache,
            .trips, .lifecycle, .performance, .charts, .parser,
            .startup, .photos, .calendar, .auth
        ]
        for cat in categories {
            let label = cat.label
            #expect(label == label.lowercased(), "Label '\(label)' should be lowercase")
            #expect(!label.isEmpty, "Label should not be empty")
        }
    }

    @Test("New categories .photos, .calendar, .auth exist")
    func newCategoriesExist() {
        #expect(LogCategory.photos.emoji == "📷")
        #expect(LogCategory.photos.label == "photos")
        #expect(LogCategory.calendar.emoji == "📅")
        #expect(LogCategory.calendar.label == "calendar")
        #expect(LogCategory.auth.emoji == "🔐")
        #expect(LogCategory.auth.label == "auth")
    }

    // MARK: - Presets

    @MainActor
    @Test("enableAll turns on all toggles")
    func enableAllPreset() {
        let config = DebugConfig.shared
        config.disableAll()
        config.enableAll()

        #expect(config.isEnabled == true)
        #expect(config.showViewNames == true)
        #expect(config.showLifecycle == true)
        #expect(config.showPerformance == true)
        #expect(config.logDataStore == true)
        #expect(config.logPersistence == true)
        #expect(config.logNavigation == true)
        #expect(config.logNetwork == true)
        #expect(config.logCache == true)
        #expect(config.logTrips == true)
        #expect(config.logCharts == true)
        #expect(config.logParser == true)
        #expect(config.logStartup == true)
        #expect(config.logPhotos == true)
        #expect(config.logCalendar == true)
        #expect(config.logAuth == true)

        // Clean up
        config.disableAll()
    }

    @MainActor
    @Test("disableAll turns off all toggles")
    func disableAllPreset() {
        let config = DebugConfig.shared
        config.enableAll()
        config.disableAll()

        #expect(config.isEnabled == false)
        #expect(config.showViewNames == false)
        #expect(config.logDataStore == false)
        #expect(config.logPhotos == false)
        #expect(config.logCalendar == false)
        #expect(config.logAuth == false)
    }

    @MainActor
    @Test("presetUI enables UI toggles and disables data toggles")
    func presetUICheck() {
        let config = DebugConfig.shared
        config.disableAll()
        config.presetUI()

        #expect(config.isEnabled == true)
        #expect(config.showViewNames == true)
        #expect(config.showLifecycle == true)
        #expect(config.logNavigation == true)
        #expect(config.logCalendar == true)
        #expect(config.logDataStore == false)
        #expect(config.logPersistence == false)
        #expect(config.logPhotos == false)
        #expect(config.logAuth == false)

        config.disableAll()
    }

    @MainActor
    @Test("presetData enables data toggles and disables UI toggles")
    func presetDataCheck() {
        let config = DebugConfig.shared
        config.disableAll()
        config.presetData()

        #expect(config.isEnabled == true)
        #expect(config.showViewNames == false)
        #expect(config.showLifecycle == false)
        #expect(config.logDataStore == true)
        #expect(config.logPersistence == true)
        #expect(config.logNetwork == true)
        #expect(config.logPhotos == true)
        #expect(config.logAuth == true)
        #expect(config.logCalendar == false)

        config.disableAll()
    }

    // MARK: - Category Gating

    @MainActor
    @Test("isEnabled gates categories correctly")
    func categoryGating() {
        let config = DebugConfig.shared
        config.disableAll()
        config.isEnabled = true

        config.logPhotos = true
        #expect(LogCategory.photos.isEnabled(in: config) == true)
        #expect(LogCategory.calendar.isEnabled(in: config) == false)

        config.logPhotos = false
        config.logCalendar = true
        #expect(LogCategory.photos.isEnabled(in: config) == false)
        #expect(LogCategory.calendar.isEnabled(in: config) == true)

        config.logAuth = true
        #expect(LogCategory.auth.isEnabled(in: config) == true)

        config.disableAll()
    }

    @MainActor
    @Test("Lifecycle and performance use UI toggles")
    func lifecyclePerformanceGating() {
        let config = DebugConfig.shared
        config.disableAll()
        config.isEnabled = true

        config.showLifecycle = true
        #expect(LogCategory.lifecycle.isEnabled(in: config) == true)

        config.showPerformance = true
        #expect(LogCategory.performance.isEnabled(in: config) == true)

        config.disableAll()
    }
}
