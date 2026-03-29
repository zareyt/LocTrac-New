//
//  DefaultLocationSettingsView.swift
//  LocTrac
//
//  Settings view for managing default location
//

import SwiftUI

struct DefaultLocationSettingsView: View {
    @EnvironmentObject var store: DataStore
    @AppStorage("defaultLocationID") private var defaultLocationID: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Default Location Picker
                Section {
                    Picker("Default Location", selection: $defaultLocationID) {
                        Text("None").tag("")
                        ForEach(store.locations) { location in
                            HStack {
                                Circle()
                                    .fill(Color(location.theme.uiColor))
                                    .frame(width: 12, height: 12)
                                Text(location.name)
                            }
                            .tag(location.id)
                        }
                    }
                } header: {
                    Label("Default Location", systemImage: "mappin.circle.fill")
                } footer: {
                    Text("This location will be automatically selected when creating new events.")
                        .font(.caption)
                }
                
                // Current Default Display
                if !defaultLocationID.isEmpty,
                   let defaultLocation = store.locations.first(where: { $0.id == defaultLocationID }) {
                    Section {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(Color(defaultLocation.theme.uiColor))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(defaultLocation.name)
                                    .font(.headline)
                                if let city = defaultLocation.city {
                                    Text(city)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                if let country = defaultLocation.country {
                                    Text(country)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Current Default")
                    }
                    
                    // Clear button
                    Section {
                        Button(role: .destructive) {
                            defaultLocationID = ""
                        } label: {
                            Label("Clear Default Location", systemImage: "xmark.circle")
                        }
                    }
                } else {
                    // No default set
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "mappin.slash.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No Default Location Set")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Select a location above to set it as default")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
                
                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Benefits", systemImage: "star.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        InfoRow(icon: "bolt.fill", text: "Faster event creation", color: .blue)
                        InfoRow(icon: "checkmark.circle.fill", text: "Consistent data entry", color: .green)
                        InfoRow(icon: "house.fill", text: "Home location always ready", color: .purple)
                        InfoRow(icon: "square.and.arrow.up.fill", text: "Can override when traveling", color: .orange)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("How It Works")
                }
            }
            .navigationTitle("Default Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
struct DefaultLocationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DefaultLocationSettingsView()
            .environmentObject(DataStore(preview: true))
    }
}
