//
//  OrphanedEventsAnalyzerView.swift
//  LocTrac
//
//  UI for analyzing and fixing orphaned events
//

import SwiftUI

struct OrphanedEventsAnalyzerView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var debugConfig: DebugConfig
    @Environment(\.dismiss) private var dismiss
    
    @State private var report: OrphanedEventsReport?
    @State private var isAnalyzing = false
    @State private var showingFixConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteDuplicatesConfirmation = false
    @State private var fixResult: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isAnalyzing {
                    ProgressView("Analyzing events...")
                        .padding()
                } else if let report = report {
                    reportView(report: report)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Fix Orphaned Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if report == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Analyze") {
                            runAnalysis()
                        }
                    }
                }
            }
            .onAppear {
                // Auto-run analysis on appear
                runAnalysis()
            }
            .alert("Reassign to 'Other'?", isPresented: $showingFixConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reassign", role: .destructive) {
                    reassignToOther()
                }
            } message: {
                if let report = report {
                    Text("This will reassign \(report.totalOrphaned) orphaned events to the 'Other' location. This cannot be undone.")
                }
            }
            .alert("Delete Orphaned Events?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteOrphaned()
                }
            } message: {
                if let report = report {
                    Text("⚠️ WARNING: This will permanently delete \(report.totalOrphaned) events. Make sure you have a backup! This cannot be undone.")
                }
            }
            .alert("Delete Duplicates Only?", isPresented: $showingDeleteDuplicatesConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteDuplicates()
                }
            } message: {
                if let report = report {
                    Text("This will delete \(report.duplicatePairs.count) duplicate events and keep \(report.orphansWithoutDuplicates.count) unique orphans. This cannot be undone.")
                }
            }
            .alert("Result", isPresented: .constant(fixResult != nil)) {
                Button("OK") {
                    fixResult = nil
                    runAnalysis() // Re-analyze after fix
                }
            } message: {
                if let result = fixResult {
                    Text(result)
                }
            }
        }
        .debugViewName("OrphanedEventsAnalyzerView")
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Orphaned Events Analyzer")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Check for events that reference deleted or missing locations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                runAnalysis()
            } label: {
                Label("Run Analysis", systemImage: "play.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
    
    // MARK: - Report View
    
    @ViewBuilder
    private func reportView(report: OrphanedEventsReport) -> some View {
        List {
            // Summary Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(report.totalEvents)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Orphaned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Text("\(report.totalOrphaned)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(report.hasOrphans ? .orange : .green)
                            Text("(\(String(format: "%.1f", report.orphanedPercentage))%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                if report.hasOrphans {
                    statusMessage(for: report)
                }
            } header: {
                Label("Analysis Summary", systemImage: "chart.bar.doc.horizontal")
            }
            
            // No orphans - success message
            if !report.hasOrphans {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("All Clear!")
                                .font(.headline)
                            Text("No orphaned events found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Orphans found - show details
            if report.hasOrphans {
                // NEW: Duplicate Detection Section
                if report.hasDuplicates {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.on.doc.fill")
                                    .foregroundColor(report.allAreDuplicates ? .green : .orange)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Duplicates Detected")
                                        .font(.headline)
                                    if report.allAreDuplicates {
                                        Text("All \(report.duplicatePairs.count) orphans appear to be duplicates")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("\(report.duplicatePairs.count) of \(report.totalOrphaned) appear to be duplicates")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            Text("These orphaned events have matching duplicates on the next day with identical city AND notes. The earlier dates (day-1) are phantom duplicates from timezone shifts; the later dates (day+0) are the correct events that need reassignment to valid locations.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        
                        // Show sample duplicate pairs
                        ForEach(report.duplicatePairs.prefix(5).indices, id: \.self) { index in
                            let pair = report.duplicatePairs[index]
                            
                            VStack(alignment: .leading, spacing: 8) {
                                // Orphan (duplicate)
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(pair.orphan.date.utcMediumDateString)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            Text("(Orphan)")
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                        }
                                        if let city = pair.orphan.city {
                                            HStack(spacing: 4) {
                                                Text(city)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                if let state = pair.orphan.state {
                                                    Text("•")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Text(state)
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        if let country = pair.orphan.country {
                                            Text(country)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        if !pair.orphan.note.isEmpty {
                                            Text("Note: \(pair.orphan.note)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                                
                                // Arrow
                                HStack {
                                    Spacer().frame(width: 24)
                                    Image(systemName: "arrow.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Valid event (day +1)
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(pair.validEvent.date.utcMediumDateString)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            Text("(Valid)")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        }
                                        HStack(spacing: 4) {
                                            if let city = pair.validEvent.city {
                                                Text(city)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                if let state = pair.validEvent.state {
                                                    Text("•")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Text(state)
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Text("•")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(pair.validEvent.location.name)
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        }
                                        if let country = pair.validEvent.country {
                                            Text(country)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        if !pair.validEvent.note.isEmpty {
                                            Text("Note: \(pair.validEvent.note)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                                
                                // Similarity score
                                HStack {
                                    Spacer()
                                    Text("Match: \(Int(pair.similarityScore))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.orange.opacity(0.05))
                            .cornerRadius(8)
                        }
                        
                        if report.duplicatePairs.count > 5 {
                            Text("+ \(report.duplicatePairs.count - 5) more duplicate pairs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    } header: {
                        Label("🔍 Duplicate Detection", systemImage: "doc.on.doc")
                    } footer: {
                        Text("The day-1 events are phantom duplicates safe to delete. The day+0 events are correct but orphaned - reassign them to valid locations after deleting duplicates.")
                    }
                }
                
                // Show orphans without matches if any
                if !report.orphansWithoutDuplicates.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("\(report.orphansWithoutDuplicates.count) orphans without matching duplicates")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Text("These events don't have a matching event on day+1. Review carefully before deleting.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        ForEach(report.orphansWithoutDuplicates.prefix(5)) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(event.date.utcMediumDateString)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(event.location.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(spacing: 4) {
                                    if let city = event.city {
                                        Text(city)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let state = event.state {
                                        Text("•")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(state)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if let country = event.country {
                                    Text(country)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !event.note.isEmpty {
                                    Text(event.note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if report.orphansWithoutDuplicates.count > 5 {
                            Text("+ \(report.orphansWithoutDuplicates.count - 5) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Label("⚠️ No Duplicate Found", systemImage: "exclamationmark.triangle")
                    } footer: {
                        Text("Review these carefully - they may contain unique data.")
                    }
                }
                
                // By City
                Section {
                    ForEach(report.topCities.prefix(10), id: \.city) { item in
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            Text(item.city)
                            
                            Spacer()
                            
                            Text("\(item.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                } header: {
                    Label("Top Cities (\(report.byCity.count) total)", systemImage: "building.2")
                }
                
                // By Country
                Section {
                    ForEach(report.topCountries.prefix(10), id: \.country) { item in
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text(item.country)
                            
                            Spacer()
                            
                            Text("\(item.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                } header: {
                    Label("By Country", systemImage: "globe")
                }
                
                // By Location Name
                Section {
                    ForEach(report.byName.sorted(by: { $0.value.count > $1.value.count }).prefix(10), id: \.key) { name, events in
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            Text(name)
                            
                            Spacer()
                            
                            Text("\(events.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                } header: {
                    Label("By Embedded Location Name", systemImage: "mappin.circle")
                }
                
                // Sample Events
                Section {
                    ForEach(report.orphanedEvents.prefix(10)) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.date.utcMediumDateString)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text(event.location.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                if let city = event.city {
                                    Text(city)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let state = event.state {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(state)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let country = event.country {
                                Text(country)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !event.note.isEmpty {
                                Text(event.note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("Sample Orphaned Events (showing \(min(10, report.orphanedEvents.count)) of \(report.totalOrphaned))", systemImage: "list.bullet")
                }
                
                // Actions Section
                Section {
                    // NEW: Delete duplicates only button
                    if report.hasDuplicates {
                        Button {
                            showingDeleteDuplicatesConfirmation = true
                        } label: {
                            HStack {
                                Label("Delete Duplicates Only", systemImage: "doc.on.doc.fill")
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("(\(report.duplicatePairs.count))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button {
                        showingFixConfirmation = true
                    } label: {
                        Label("Reassign All to 'Other' Location", systemImage: "arrow.triangle.branch")
                            .foregroundColor(.blue)
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete All Orphaned Events", systemImage: "trash")
                    }
                } header: {
                    Label("Actions", systemImage: "wrench.and.screwdriver.fill")
                } footer: {
                    if report.hasDuplicates {
                        Text("💡 Recommended: Delete duplicates (day-1 phantoms), then reassign remaining orphans (day+0 correct events) to valid locations like 'Other'.")
                    } else {
                        Text("⚠️ Make sure you have a backup before performing any actions. These changes cannot be undone.")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    @ViewBuilder
    private func statusMessage(for report: OrphanedEventsReport) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: report.orphanedPercentage < 5 ? "info.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(report.orphanedPercentage < 5 ? .blue : .orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle(for: report))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(statusDescription(for: report))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusTitle(for report: OrphanedEventsReport) -> String {
        if report.orphanedPercentage < 5 {
            return "Low Impact"
        } else if report.orphanedPercentage < 15 {
            return "Moderate Amount"
        } else {
            return "High Percentage"
        }
    }
    
    private func statusDescription(for report: OrphanedEventsReport) -> String {
        if report.orphanedPercentage < 5 {
            return "Small percentage of events affected. Safe to reassign to 'Other' location or ignore."
        } else if report.orphanedPercentage < 15 {
            return "Consider reviewing common cities and creating locations for them, then reassigning the rest to 'Other'."
        } else {
            return "Significant portion of events affected. Investigate the cause before taking action. This may indicate a data migration or import issue."
        }
    }
    
    // MARK: - Actions
    
    private func runAnalysis() {
        isAnalyzing = true
        
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // Small delay for UI
            
            let analyzer = OrphanedEventsAnalyzer(store: store)
            let result = analyzer.analyze()
            
            await MainActor.run {
                report = result
                isAnalyzing = false
                
                #if DEBUG
                analyzer.printAnalysis()
                #endif
            }
        }
    }
    
    private func reassignToOther() {
        let analyzer = OrphanedEventsAnalyzer(store: store)
        let fixed = analyzer.reassignAllToOther()
        
        fixResult = "Successfully reassigned \(fixed) events to 'Other' location"
    }
    
    private func deleteOrphaned() {
        let analyzer = OrphanedEventsAnalyzer(store: store)
        let deleted = analyzer.deleteOrphanedEvents()
        
        fixResult = "Deleted \(deleted) orphaned events"
    }
    
    private func deleteDuplicates() {
        let analyzer = OrphanedEventsAnalyzer(store: store)
        let result = analyzer.deleteDuplicatesOnly()
        
        fixResult = "Deleted \(result.deleted) duplicate events.\nKept \(result.remaining) unique orphans for review."
    }
}

// MARK: - Preview

struct OrphanedEventsAnalyzerView_Previews: PreviewProvider {
    static var previews: some View {
        OrphanedEventsAnalyzerView()
            .environmentObject(DataStore(preview: true))
    }
}
