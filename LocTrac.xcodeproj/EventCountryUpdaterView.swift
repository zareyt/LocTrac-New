//
//  EventCountryUpdaterView.swift
//  LocTrac
//
//  User-friendly interface for updating event countries
//

import SwiftUI

struct EventCountryUpdaterView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var currentEvent = 0
    @State private var totalEvents = 0
    @State private var updatedCount = 0
    @State private var failedCount = 0
    @State private var isComplete = false
    @State private var eventsNeedingUpdate: [Event] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if !isProcessing && !isComplete {
                    setupView
                } else if isProcessing {
                    processingView
                } else {
                    resultsView
                }
            }
            .padding()
            .navigationTitle("Update Event Countries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .onAppear {
                analyzeEvents()
            }
        }
    }
    
    // MARK: - Setup View
    private var setupView: some View {
        VStack(spacing: 24) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Update Event Countries")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This will automatically detect and fill in missing country information for your events.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: "doc.text.magnifyingglass",
                    title: "Parse City Names",
                    description: "Extract country from \"Caen, France\" or \"Denver, CO\""
                )
                
                InfoRow(
                    icon: "location.fill",
                    title: "Geocode Coordinates",
                    description: "Look up country from GPS coordinates"
                )
                
                InfoRow(
                    icon: "shield.fill",
                    title: "Safe Process",
                    description: "Only updates events with missing countries"
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Total Events:")
                    Spacer()
                    Text("\(store.events.count)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Events Needing Update:")
                    Spacer()
                    Text("\(eventsNeedingUpdate.count)")
                        .fontWeight(.semibold)
                        .foregroundColor(eventsNeedingUpdate.count > 0 ? .orange : .green)
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
            
            Spacer()
            
            Button {
                startUpdate()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Update \(eventsNeedingUpdate.count) Event\(eventsNeedingUpdate.count == 1 ? "" : "s")")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(eventsNeedingUpdate.count > 0 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(eventsNeedingUpdate.isEmpty)
        }
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView(value: progress, total: Double(totalEvents))
                .progressViewStyle(.linear)
            
            Text("Processing event \(currentEvent) of \(totalEvents)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 40) {
                VStack {
                    Text("\(updatedCount)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Updated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(failedCount)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Failed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            Text("Please wait...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 24) {
            Image(systemName: updatedCount > 0 ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(updatedCount > 0 ? .green : .blue)
            
            Text("Update Complete!")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                ResultRow(
                    icon: "checkmark.circle.fill",
                    title: "Successfully Updated",
                    count: updatedCount,
                    color: .green
                )
                
                ResultRow(
                    icon: "xmark.circle.fill",
                    title: "Could Not Update",
                    count: failedCount,
                    color: .orange
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            if updatedCount > 0 {
                Text("Your events have been updated with country information.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func analyzeEvents() {
        eventsNeedingUpdate = store.events.filter { event in
            let hasCountry = (event.country ?? event.location.country) != nil &&
                           !(event.country ?? event.location.country)!.isEmpty
            return !hasCountry
        }
        totalEvents = eventsNeedingUpdate.count
    }
    
    private func startUpdate() {
        isProcessing = true
        currentEvent = 0
        updatedCount = 0
        failedCount = 0
        progress = 0
        
        Task {
            for (index, event) in eventsNeedingUpdate.enumerated() {
                currentEvent = index + 1
                progress = Double(currentEvent) / Double(totalEvents)
                
                if let updatedEvent = await EventCountryGeocoder.updateCountry(for: event, store: store) {
                    store.update(updatedEvent)
                    updatedCount += 1
                } else {
                    failedCount += 1
                }
                
                // Rate limit to avoid API throttling
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            
            // Save changes
            if updatedCount > 0 {
                store.storeData()
            }
            
            isProcessing = false
            isComplete = true
        }
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ResultRow: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
            Spacer()
            Text("\(count)")
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview
struct EventCountryUpdaterView_Previews: PreviewProvider {
    static var previews: some View {
        EventCountryUpdaterView()
            .environmentObject(DataStore(preview: true))
    }
}
