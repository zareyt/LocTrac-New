//
//  EventCountryUpdaterView.swift
//  LocTrac
//
//  View for updating country data for events
//

import SwiftUI

struct EventCountryUpdaterView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    
    enum ViewState {
        case initial
        case analyzingPreview
        case showingPreview([EventCountryPreview])
        case applyingUpdates
        case complete(updated: Int, failed: Int)
    }
    
    @State private var viewState: ViewState = .initial
    @State private var eventsNeedingUpdate: Int = 0
    @State private var progressCurrent: Int = 0
    @State private var progressTotal: Int = 0
    @State private var currentEventCity: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch viewState {
                case .initial:
                    initialView
                    
                case .analyzingPreview:
                    analyzingView
                    
                case .showingPreview(let previews):
                    previewView(previews: previews)
                    
                case .applyingUpdates:
                    applyingView
                    
                case .complete(let updated, let failed):
                    completeView(updated: updated, failed: failed)
                }
                
                Spacer()
            }
            .navigationTitle("Update Countries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                calculateEventsNeedingUpdate()
            }
        }
    }
    
    // MARK: - Initial View
    
    private var initialView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe.americas")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Update Event Countries")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This will analyze events missing country information and update them by geocoding coordinates or parsing city names.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            if eventsNeedingUpdate > 0 {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("\(eventsNeedingUpdate) events need updating")
                            .font(.headline)
                    }
                    
                    Text("Step 1: Preview changes before applying")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button {
                Task {
                    await generatePreview()
                }
            } label: {
                Label("Preview Changes", systemImage: "eye.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .disabled(eventsNeedingUpdate == 0)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Analyzing View
    
    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: Double(progressCurrent), total: Double(progressTotal)) {
                Text("Analyzing Events...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(progressCurrent) / \(progressTotal)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
            if !currentEventCity.isEmpty {
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundStyle(.blue)
                    Text(currentEventCity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
            
            Text("This may take a moment while geocoding...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Preview View
    
    private func previewView(previews: [EventCountryPreview]) -> some View {
        let updatable = previews.filter { $0.proposedCountry != nil && $0.source != .noChange }
        let _ = previews.filter { $0.source == .noChange }.count  // Silence unused warning
        let failed = previews.filter { $0.source == .failed }.count
        
        return VStack(spacing: 16) {
            // Summary cards
            HStack(spacing: 12) {
                summaryCard(
                    count: updatable.count,
                    label: "Will Update",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                summaryCard(
                    count: failed,
                    label: "Failed",
                    color: .orange,
                    icon: "exclamationmark.triangle.fill"
                )
            }
            .padding(.horizontal)
            
            // Updatable events list
            if !updatable.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Events to Update")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(updatable.prefix(50)) { preview in
                                previewRow(preview: preview)
                            }
                            
                            if updatable.count > 50 {
                                Text("... and \(updatable.count - 50) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Apply button
            Button {
                Task {
                    await applyUpdates(previews: previews)
                }
            } label: {
                Label("Apply Updates", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(updatable.isEmpty ? Color.gray : Color.green)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .disabled(updatable.isEmpty)
            .padding(.horizontal)
        }
    }
    
    private func summaryCard(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.title.bold())
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func previewRow(preview: EventCountryPreview) -> some View {
        HStack(spacing: 12) {
            Image(systemName: preview.source == .cityParsing ? "text.quote" : "location.fill")
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(preview.city)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let proposed = preview.proposedCountry {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(proposed)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(preview.source == .cityParsing ? "Parsed from city" : "Geocoded")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Applying View
    
    private var applyingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: Double(progressCurrent), total: Double(progressTotal)) {
                Text("Applying Updates...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(progressCurrent) / \(progressTotal)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
            if !currentEventCity.isEmpty {
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundStyle(.green)
                    Text(currentEventCity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
    
    // MARK: - Complete View
    
    private func completeView(updated: Int, failed: Int) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Update Complete")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Updated:")
                    Spacer()
                    Text("\(updated)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                
                HStack {
                    Text("Skipped/Failed:")
                    Spacer()
                    Text("\(failed)")
                        .fontWeight(.semibold)
                        .foregroundStyle(failed > 0 ? .orange : .secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            Text("All changes have been saved")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func calculateEventsNeedingUpdate() {
        print("📊 [View] Calculating events needing updates...")
        
        // First, let's see what locations we have
        let locationBreakdown = Dictionary(grouping: store.events, by: { $0.location.name })
        print("📊 [Debug] Location breakdown:")
        for (locationName, events) in locationBreakdown.sorted(by: { $0.key < $1.key }) {
            print("   - '\(locationName)': \(events.count) events")
        }
        
        let otherLocationEvents = store.events.filter { $0.location.name == "Other" }
        print("📊 [Debug] Total 'Other' location events: \(otherLocationEvents.count)")
        print("📊 [Debug] ========== CHECKING ALL 'Other' EVENTS ==========")
        
        var debugCount = 0
        eventsNeedingUpdate = otherLocationEvents.filter { event in
            let eventCountry = event.country
            let locationCountry = event.location.country
            let combinedCountry = eventCountry ?? locationCountry
            
            // Debug logging for EVERY event
            debugCount += 1
            let countryDisplay = combinedCountry ?? "nil"
            print("📊 [\(debugCount)] '\(event.city ?? "Unknown")': event.country='\(eventCountry ?? "nil")', location.country='\(locationCountry ?? "nil")', combined='\(countryDisplay)'")
            
            // Needs update if: country is nil, empty string, or "Unknown"
            guard let country = combinedCountry else { 
                print("   ✅ NEEDS UPDATE (nil)")
                return true 
            }
            
            let needsUpdate = country.isEmpty || country.lowercased() == "unknown"
            if needsUpdate {
                print("   ✅ NEEDS UPDATE (\(country.isEmpty ? "empty" : "unknown"))")
            }
            return needsUpdate
        }.count
        
        print("📊 [Debug] ========== END OF CHECK ==========")
        print("📊 [View] Found \(eventsNeedingUpdate) events needing updates out of \(otherLocationEvents.count) 'Other' events")
    }
    
    private func generatePreview() async {
        print("🔍 [View] Starting preview generation...")
        viewState = .analyzingPreview
        progressCurrent = 0
        progressTotal = eventsNeedingUpdate
        
        let previews = await EventCountryGeocoder.generatePreview(store: store) { progress in
            Task { @MainActor in
                self.progressCurrent = progress.current
                self.progressTotal = progress.total
                self.currentEventCity = progress.eventCity
            }
        }
        
        print("✅ [View] Preview generation complete with \(previews.count) results")
        viewState = .showingPreview(previews)
    }
    
    private func applyUpdates(previews: [EventCountryPreview]) async {
        print("🚀 [View] Starting to apply updates...")
        viewState = .applyingUpdates
        progressCurrent = 0
        
        let updatable = previews.filter { $0.proposedCountry != nil && $0.source != .noChange }
        progressTotal = updatable.count
        
        let result = await EventCountryGeocoder.applyUpdates(previews: previews, store: store) { progress in
            Task { @MainActor in
                self.progressCurrent = progress.current
                self.progressTotal = progress.total
                self.currentEventCity = progress.eventCity
            }
        }
        
        print("✅ [View] Updates applied: \(result.updated) updated, \(result.failed) failed")
        viewState = .complete(updated: result.updated, failed: result.failed)
    }
}

#Preview {
    EventCountryUpdaterView()
        .environmentObject(DataStore())
}
