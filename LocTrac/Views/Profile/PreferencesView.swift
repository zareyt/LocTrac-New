// PreferencesView.swift
// LocTrac
// App preferences — default location, distance unit, default transport mode
// v2.0

import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var store: DataStore

    @State private var distanceUnit: UserProfile.DistanceUnit = .miles
    @State private var defaultLocationID: String?
    @State private var defaultTransportMode: String?
    @State private var defaultEventType: String?

    private let transportModes = ["driving", "flying", "train", "bus", "walking", "cycling", "boat"]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Distance Unit
                    preferencesSection("DISTANCE UNIT") {
                        Picker("Distance Unit", selection: $distanceUnit) {
                            Text("Miles").tag(UserProfile.DistanceUnit.miles)
                            Text("Kilometers").tag(UserProfile.DistanceUnit.kilometers)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Default Location
                    preferencesSection("DEFAULT LOCATION") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Used when creating new stays")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)

                            Picker("Default Location", selection: $defaultLocationID) {
                                Text("None").tag(String?.none)
                                ForEach(store.locations.sorted(by: { $0.name < $1.name })) { location in
                                    Text(location.name).tag(String?.some(location.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.accentColor)
                        }
                    }

                    // Default Event Type
                    preferencesSection("DEFAULT EVENT TYPE") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pre-selected when creating new stays")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)

                            Picker("Default Event Type", selection: $defaultEventType) {
                                Text("None").tag(String?.none)
                                ForEach(store.eventTypes) { item in
                                    Label(item.displayName, systemImage: item.sfSymbol)
                                        .foregroundStyle(item.color)
                                        .tag(String?.some(item.name))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.accentColor)
                        }
                    }

                    // Default Transport Mode
                    preferencesSection("DEFAULT TRANSPORT MODE") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Used when creating new trips")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)

                            Picker("Transport Mode", selection: $defaultTransportMode) {
                                Text("None").tag(String?.none)
                                ForEach(transportModes, id: \.self) { mode in
                                    Text(mode.capitalized).tag(String?.some(mode))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.accentColor)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    savePreferences()
                    dismiss()
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.accentColor)
            }
        }
        .onAppear {
            if let profile = authState.currentUser {
                distanceUnit = profile.distanceUnit
                defaultLocationID = profile.defaultLocationID
                defaultTransportMode = profile.defaultTransportMode
                defaultEventType = profile.defaultEventType
            }
            // Load from UserDefaults (covers guests and ensures sync)
            if defaultLocationID == nil {
                defaultLocationID = UserDefaults.standard.string(forKey: "defaultLocationID")
            }
            if defaultEventType == nil {
                defaultEventType = UserDefaults.standard.string(forKey: "defaultEventType")
            }
            if defaultTransportMode == nil {
                defaultTransportMode = UserDefaults.standard.string(forKey: "defaultTransportMode")
            }
        }
        .debugViewName("PreferencesView")
    }

    private func preferencesSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .tracking(1.5)
                .padding(.horizontal, 8)

            VStack {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
            )
        }
        .padding(.horizontal, 24)
    }

    private func savePreferences() {
        // Sync all preferences to UserDefaults so forms can read without auth state
        if let locationID = defaultLocationID {
            UserDefaults.standard.set(locationID, forKey: "defaultLocationID")
        } else {
            UserDefaults.standard.removeObject(forKey: "defaultLocationID")
        }
        if let eventType = defaultEventType {
            UserDefaults.standard.set(eventType, forKey: "defaultEventType")
        } else {
            UserDefaults.standard.removeObject(forKey: "defaultEventType")
        }
        if let transport = defaultTransportMode {
            UserDefaults.standard.set(transport, forKey: "defaultTransportMode")
        } else {
            UserDefaults.standard.removeObject(forKey: "defaultTransportMode")
        }

        // Also save to UserProfile if signed in
        guard var profile = authState.currentUser else { return }
        profile.distanceUnit = distanceUnit
        profile.defaultLocationID = defaultLocationID
        profile.defaultTransportMode = defaultTransportMode
        profile.defaultEventType = defaultEventType
        authState.updateProfile(profile)
        #if DEBUG
        print("✅ [Preferences] Saved: unit=\(distanceUnit.rawValue), location=\(defaultLocationID ?? "none"), transport=\(defaultTransportMode ?? "none"), eventType=\(defaultEventType ?? "none")")
        #endif
    }
}

#Preview {
    NavigationStack {
        PreferencesView()
    }
    .environmentObject(AuthState())
    .environmentObject(DataStore())
}
