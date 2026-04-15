//
//  OrphanedEventsAnalyzer.swift
//  LocTrac
//
//  Diagnostic utility to analyze and fix orphaned events
//

import Foundation

@MainActor
class OrphanedEventsAnalyzer {
    let store: DataStore
    
    init(store: DataStore) {
        self.store = store
    }
    
    // MARK: - Analysis
    
    func analyze() -> OrphanedEventsReport {
        let validLocationIDs = Set(store.locations.map { $0.id })
        let orphaned = store.events.filter { event in
            !validLocationIDs.contains(event.location.id)
        }
        
        let byName = Dictionary(grouping: orphaned) { $0.location.name }
        let byCity = Dictionary(grouping: orphaned) { $0.city ?? "No city" }
        let byCountry = Dictionary(grouping: orphaned) { $0.country ?? "No country" }
        
        // NEW: Detect potential duplicates (orphans with matching event day+1)
        let duplicatePairs = findDuplicatePairs(orphaned: orphaned)
        let orphansWithoutDuplicates = orphaned.filter { orphan in
            !duplicatePairs.contains(where: { $0.orphan.id == orphan.id })
        }
        
        return OrphanedEventsReport(
            totalOrphaned: orphaned.count,
            totalEvents: store.events.count,
            orphanedEvents: orphaned,
            byName: byName,
            byCity: byCity,
            byCountry: byCountry,
            duplicatePairs: duplicatePairs,
            orphansWithoutDuplicates: orphansWithoutDuplicates
        )
    }
    
    // NEW: Find orphaned events that appear to be timezone-shifted duplicates
    // Strategy: Look for orphans on day-1 that match another orphan on day+0
    private func findDuplicatePairs(orphaned: [Event]) -> [DuplicatePair] {
        var pairs: [DuplicatePair] = []
        
        // Sort orphans by date for easier day+1 matching
        let sortedOrphans = orphaned.sorted { $0.date.startOfDay < $1.date.startOfDay }
        
        for orphan in sortedOrphans {
            // DEBUG: Look for our specific test case
            let isTestCase = orphan.date.formatted(date: .abbreviated, time: .omitted).contains("Apr 2, 2022") &&
                            (orphan.city ?? "").lowercased().contains("chicago") &&
                            orphan.note.contains("Catherine")
            
            if isTestCase {
                print("\n🔍 DEBUG: Found test case orphan (Apr 2):")
                print("   Date: \(orphan.date.formatted(date: .abbreviated, time: .omitted))")
                print("   FULL DATE: \(orphan.date)")
                print("   Start of Day: \(orphan.date.startOfDay)")
                print("   Event ID: \(orphan.id)")
                print("   Location: \(orphan.location.name) (ID: \(orphan.location.id))")
                print("   City: '\(orphan.city ?? "nil")'")
                print("   State: '\(orphan.state ?? "nil")'")
                print("   Country: '\(orphan.country ?? "nil")'")
                print("   Note: '\(orphan.note)'")
            }
            
            // Look for ANOTHER ORPHAN on the next day with matching data
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: orphan.date.startOfDay)!
            
            if isTestCase {
                print("\n   Looking for ORPHAN matches on: \(nextDay.formatted(date: .abbreviated, time: .omitted))")
                
                // DEBUG: Show ALL events on Apr 3, 2022 (valid AND orphaned)
                let apr3Events = store.events.filter { event in
                    event.date.startOfDay == nextDay
                }
                
                print("\n   🔍 ALL EVENTS ON APR 3, 2022 (total: \(apr3Events.count)):")
                for (index, event) in apr3Events.enumerated() {
                    let validLocationIDs = Set(store.locations.map { $0.id })
                    let isValid = validLocationIDs.contains(event.location.id)
                    print("   \(index + 1). \(isValid ? "✅ VALID" : "❌ ORPHAN")")
                    print("      Event ID: \(event.id)")
                    print("      FULL DATE: \(event.date)")
                    print("      Start of Day: \(event.date.startOfDay)")
                    print("      Location: \(event.location.name) (ID: \(event.location.id))")
                    print("      City: '\(event.city ?? "nil")'")
                    print("      State: '\(event.state ?? "nil")'")
                    print("      Country: '\(event.country ?? "nil")'")
                    print("      Note: '\(event.note.isEmpty ? "(empty)" : event.note)'")
                    print("")
                }
            }
            
            // Find potential matches: ANOTHER ORPHAN on day+1 with same city AND notes
            // (This catches timezone-shifted duplicates where day-1 is phantom, day+0 is real)
            let nextDayOrphans = sortedOrphans.filter { otherOrphan in
                let sameDate = otherOrphan.date.startOfDay == nextDay
                
                // Don't match with self
                guard otherOrphan.id != orphan.id else { return false }
                
                if isTestCase && sameDate {
                    print("\n   📅 Found orphan on correct date (Apr 3):")
                    print("      Event ID: \(otherOrphan.id)")
                    print("      Location: \(otherOrphan.location.name) (ID: \(otherOrphan.location.id))")
                    print("      City: '\(otherOrphan.city ?? "nil")'")
                    print("      State: '\(otherOrphan.state ?? "nil")'")
                    print("      Country: '\(otherOrphan.country ?? "nil")'")
                    print("      Note: '\(otherOrphan.note)'")
                }
                
                // City match (required) - normalize for comparison
                let orphanCity = (orphan.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let otherCity = (otherOrphan.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let cityMatch = !orphanCity.isEmpty && orphanCity == otherCity
                
                // State match (recommended)
                let orphanState = (orphan.state ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let otherState = (otherOrphan.state ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let stateMatch = !orphanState.isEmpty && !otherState.isEmpty && orphanState == otherState
                
                // Country match (recommended)
                let orphanCountry = (orphan.country ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let otherCountry = (otherOrphan.country ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let countryMatch = !orphanCountry.isEmpty && !otherCountry.isEmpty && orphanCountry == otherCountry
                
                // Notes match (required) - exact match
                let notesMatch = orphan.note == otherOrphan.note
                
                if isTestCase && sameDate {
                    print("      City match: \(cityMatch) (orphan: '\(orphanCity)' vs other: '\(otherCity)')")
                    print("      State match: \(stateMatch) (orphan: '\(orphanState)' vs other: '\(otherState)')")
                    print("      Country match: \(countryMatch) (orphan: '\(orphanCountry)' vs other: '\(otherCountry)')")
                    print("      Notes match: \(notesMatch)")
                }
                
                // MUST have: correct date AND matching city AND matching notes
                let basicMatch = sameDate && cityMatch && notesMatch
                
                // Optionally require state match if both have the data
                let locationMatch = (!orphanState.isEmpty && !otherState.isEmpty) ? stateMatch : true
                let fullMatch = basicMatch && locationMatch
                
                if isTestCase && sameDate {
                    print("      Final match result: \(fullMatch)\n")
                }
                
                return fullMatch
            }
            
            if isTestCase {
                print("   Total orphan matches found: \(nextDayOrphans.count)")
                if nextDayOrphans.isEmpty {
                    print("   ❌ NO ORPHAN MATCHES FOUND FOR TEST CASE\n")
                }
            }
            
            // The day-1 event is the phantom duplicate, day+0 is the "correct" event
            if let match = nextDayOrphans.first {
                let similarity = calculateSimilarity(orphan: orphan, valid: match)
                pairs.append(DuplicatePair(
                    orphan: orphan,          // This is the phantom (day-1)
                    validEvent: match,       // This is the "correct" orphan (day+0)
                    similarityScore: similarity
                ))
                
                if isTestCase {
                    print("   ✅ MATCH ADDED with similarity: \(similarity)%")
                    print("      Phantom (delete): \(orphan.date.formatted(date: .abbreviated, time: .omitted))")
                    print("      Correct (keep): \(match.date.formatted(date: .abbreviated, time: .omitted))\n")
                }
            }
        }
        
        return pairs.sorted { $0.similarityScore > $1.similarityScore }
    }
    
    // Calculate similarity score between orphan and valid event
    private func calculateSimilarity(orphan: Event, valid: Event) -> Double {
        var score = 0.0
        
        // City match (30 points) - REQUIRED for duplicate detection
        let orphanCity = (orphan.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let validCity = (valid.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !orphanCity.isEmpty && orphanCity == validCity {
            score += 30.0
        }
        
        // State match (15 points) - strongly recommended
        let orphanState = (orphan.state ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let validState = (valid.state ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !orphanState.isEmpty && orphanState == validState {
            score += 15.0
        }
        
        // Country match (15 points) - strongly recommended
        let orphanCountry = (orphan.country ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let validCountry = (valid.country ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !orphanCountry.isEmpty && orphanCountry == validCountry {
            score += 15.0
        }
        
        // Notes match (40 points) - REQUIRED for duplicate detection
        if orphan.note == valid.note {
            score += 40.0
        }
        
        return score
    }
    
    func printAnalysis() {
        let report = analyze()
        
        print("\n📊 ========== ORPHANED EVENTS ANALYSIS ==========")
        print("Total events: \(report.totalEvents)")
        print("Orphaned events: \(report.totalOrphaned) (\(String(format: "%.1f", report.orphanedPercentage))%)")
        print("\n✅ Valid locations in store: \(store.locations.count)")
        for loc in store.locations {
            print("   - \(loc.name) (ID: \(loc.id))")
        }
        
        // NEW: Show duplicate detection results
        print("\n🔍 DUPLICATE DETECTION:")
        print("Likely duplicates found: \(report.duplicatePairs.count)")
        print("Orphans without matches: \(report.orphansWithoutDuplicates.count)")
        
        if !report.duplicatePairs.isEmpty {
            print("\n📋 DUPLICATE PAIRS (Orphan → Valid Event Day+1):")
            for pair in report.duplicatePairs.prefix(20) {
                print("\n   ⚠️  ORPHAN:")
                print("      Date: \(pair.orphan.date.formatted(date: .abbreviated, time: .omitted))")
                print("      Location: \(pair.orphan.location.name)")
                print("      City: \(pair.orphan.city ?? "none")")
                print("      State: \(pair.orphan.state ?? "none")")
                print("      Country: \(pair.orphan.country ?? "none")")
                print("      Note: \(pair.orphan.note.isEmpty ? "(empty)" : pair.orphan.note.prefix(50).description)")
                
                print("   ✅  VALID EVENT (Day+1):")
                print("      Date: \(pair.validEvent.date.formatted(date: .abbreviated, time: .omitted))")
                print("      Location: \(pair.validEvent.location.name)")
                print("      City: \(pair.validEvent.city ?? "none")")
                print("      State: \(pair.validEvent.state ?? "none")")
                print("      Country: \(pair.validEvent.country ?? "none")")
                print("      Note: \(pair.validEvent.note.isEmpty ? "(empty)" : pair.validEvent.note.prefix(50).description)")
                print("      Similarity: \(Int(pair.similarityScore))%")
            }
            
            if report.duplicatePairs.count > 20 {
                print("\n   ... and \(report.duplicatePairs.count - 20) more duplicate pairs")
            }
        }
        
        if !report.orphansWithoutDuplicates.isEmpty {
            print("\n⚠️  ORPHANS WITHOUT MATCHING DUPLICATES (\(report.orphansWithoutDuplicates.count)):")
            for orphan in report.orphansWithoutDuplicates.prefix(10) {
                print("   - \(orphan.date.formatted(date: .abbreviated, time: .omitted)): \(orphan.location.name) in \(orphan.city ?? "unknown"), \(orphan.country ?? "unknown")")
                if !orphan.note.isEmpty {
                    print("     Note: \(orphan.note.prefix(50))")
                }
            }
            if report.orphansWithoutDuplicates.count > 10 {
                print("   ... and \(report.orphansWithoutDuplicates.count - 10) more")
            }
        }
        
        print("\n⚠️  Orphaned events by embedded location name:")
        for (name, events) in report.byName.sorted(by: { $0.value.count > $1.value.count }) {
            print("   \(name): \(events.count) events")
        }
        
        print("\n🌍 Orphaned events by city:")
        for (city, events) in report.byCity.sorted(by: { $0.value.count > $1.value.count }).prefix(10) {
            print("   \(city): \(events.count) events")
        }
        
        print("\n🗺️  Orphaned events by country:")
        for (country, events) in report.byCountry.sorted(by: { $0.value.count > $1.value.count }) {
            print("   \(country): \(events.count) events")
        }
        
        print("\n💡 Recommendations:")
        if report.totalOrphaned == 0 {
            print("   ✅ No orphaned events found!")
        } else if report.duplicatePairs.count == report.totalOrphaned {
            print("   ✅ ALL orphaned events appear to be duplicates!")
            print("      → Safe to delete all \(report.totalOrphaned) orphaned events")
        } else if Double(report.duplicatePairs.count) / Double(report.totalOrphaned) > 0.9 {
            print("   ⚠️  Most (\(report.duplicatePairs.count)/\(report.totalOrphaned)) appear to be duplicates")
            print("      → Review the \(report.orphansWithoutDuplicates.count) without matches before deleting")
        } else {
            print("   ⚠️  Only \(report.duplicatePairs.count) of \(report.totalOrphaned) appear to be duplicates")
            print("      → Carefully review before taking action")
        }
        
        print("\n=================================================\n")
    }
    
    // MARK: - Fixes
    
    func deleteDuplicatesOnly() -> (deleted: Int, remaining: Int) {
        let report = analyze()
        let duplicateIDs = Set(report.duplicatePairs.map { $0.orphan.id })
        
        let beforeCount = store.events.count
        store.events.removeAll { event in
            duplicateIDs.contains(event.id)
        }
        let deleted = beforeCount - store.events.count
        
        if deleted > 0 {
            store.save()
            print("🗑️  Deleted \(deleted) duplicate orphaned events")
            print("⚠️  Kept \(report.orphansWithoutDuplicates.count) orphans without matches")
        }
        
        return (deleted: deleted, remaining: report.orphansWithoutDuplicates.count)
    }
    
    func reassignAllToOther() -> Int {
        guard let otherLocation = store.locations.first(where: { $0.name == "Other" }) else {
            print("❌ 'Other' location not found!")
            return 0
        }
        
        let validLocationIDs = Set(store.locations.map { $0.id })
        var fixedCount = 0
        
        for i in store.events.indices {
            if !validLocationIDs.contains(store.events[i].location.id) {
                store.events[i].location = otherLocation
                fixedCount += 1
            }
        }
        
        if fixedCount > 0 {
            store.save()
            print("✅ Reassigned \(fixedCount) orphaned events to 'Other' location")
        }
        
        return fixedCount
    }
    
    func deleteOrphanedEvents() -> Int {
        let validLocationIDs = Set(store.locations.map { $0.id })
        let beforeCount = store.events.count
        
        store.events.removeAll { event in
            !validLocationIDs.contains(event.location.id)
        }
        
        let deleted = beforeCount - store.events.count
        
        if deleted > 0 {
            store.save()
            print("🗑️  Deleted \(deleted) orphaned events")
        }
        
        return deleted
    }
}

// MARK: - Report Model

struct DuplicatePair {
    let orphan: Event
    let validEvent: Event
    let similarityScore: Double
}

struct OrphanedEventsReport {
    let totalOrphaned: Int
    let totalEvents: Int
    let orphanedEvents: [Event]
    let byName: [String: [Event]]
    let byCity: [String: [Event]]
    let byCountry: [String: [Event]]
    let duplicatePairs: [DuplicatePair]
    let orphansWithoutDuplicates: [Event]
    
    var orphanedPercentage: Double {
        guard totalEvents > 0 else { return 0 }
        return Double(totalOrphaned) / Double(totalEvents) * 100.0
    }
    
    var hasOrphans: Bool {
        totalOrphaned > 0
    }
    
    var hasDuplicates: Bool {
        !duplicatePairs.isEmpty
    }
    
    var allAreDuplicates: Bool {
        duplicatePairs.count == totalOrphaned
    }
    
    var topCities: [(city: String, count: Int)] {
        byCity.map { (city: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
    
    var topCountries: [(country: String, count: Int)] {
        byCountry.map { (country: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
}

// MARK: - Usage Examples

/*
 // In your code or debug menu:
 
 let analyzer = OrphanedEventsAnalyzer(store: store)
 
 // Print detailed analysis
 analyzer.printAnalysis()
 
 // Get report programmatically
 let report = analyzer.analyze()
 if report.hasOrphans {
     print("Found \(report.totalOrphaned) orphaned events")
 }
 
 // Fix by reassigning to "Other"
 let fixed = analyzer.reassignAllToOther()
 print("Fixed \(fixed) events")
 
 // OR delete orphans (⚠️ WARNING: Destructive! Backup first!)
 // let deleted = analyzer.deleteOrphanedEvents()
 */
