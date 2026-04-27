// PreferencesView.swift
// LocTrac
// App preferences — default location, distance unit, default transport mode, HealthKit
// v2.1

import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var store: DataStore

    @State private var distanceUnit: UserProfile.DistanceUnit = .miles
    @State private var defaultLocationID: String?
    @State private var defaultTransportMode: String?
    @State private var defaultEventType: String?

    // HealthKit
    @State private var healthKitEnabled: Bool = false
    @State private var healthKitSyncReminderDays: Int = 7
    @State private var isSyncing: Bool = false
    @State private var syncResultMessage: String?
    @State private var showSyncAlert: Bool = false
    @State private var showSyncSummary: Bool = false
    @State private var lastSyncResult: HealthKitService.SyncResult?

    private let transportModes = ["driving", "flying", "train", "bus", "walking", "cycling", "boat"]
    private let reminderDayOptions = [3, 7, 14, 30]

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

                    // Health & Fitness
                    preferencesSection("HEALTH & FITNESS") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Sync with Apple Health", isOn: $healthKitEnabled)
                                .tint(Color.accentColor)
                                .onChange(of: healthKitEnabled) { _, newValue in
                                    if newValue {
                                        requestHealthKitAccess()
                                    }
                                }

                            if healthKitEnabled {
                                Divider()

                                // Last synced
                                if let lastSync = authState.currentUser?.lastHealthKitSync {
                                    HStack {
                                        Text("Last synced")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(lastSync.utcMediumDateString)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Not yet synced")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }

                                Divider()

                                // Sync reminder interval
                                HStack {
                                    Text("Sync Reminder")
                                        .font(.system(size: 15))
                                    Spacer()
                                    Picker("", selection: $healthKitSyncReminderDays) {
                                        ForEach(reminderDayOptions, id: \.self) { days in
                                            Text("\(days) days").tag(days)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Color.accentColor)
                                }

                                Text("Remind if not synced for this many days")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)

                                Divider()

                                // Sync Now button
                                Button {
                                    performSync()
                                } label: {
                                    HStack {
                                        if isSyncing {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Syncing...")
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                            Text("Sync Now")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                                .disabled(isSyncing)
                                .buttonStyle(.borderedProminent)
                                .tint(Color.accentColor)
                            }
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
        .alert("HealthKit", isPresented: $showSyncAlert) {
            Button("OK") { }
        } message: {
            Text(syncResultMessage ?? "")
        }
        .sheet(isPresented: $showSyncSummary) {
            if let result = lastSyncResult {
                SyncSummarySheet(result: result, store: store, authState: authState)
            }
        }
        .onAppear {
            if let profile = authState.currentUser {
                distanceUnit = profile.distanceUnit
                defaultLocationID = profile.defaultLocationID
                defaultTransportMode = profile.defaultTransportMode
                defaultEventType = profile.defaultEventType
                healthKitEnabled = profile.healthKitEnabled
                healthKitSyncReminderDays = profile.healthKitSyncReminderDays
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
        profile.healthKitEnabled = healthKitEnabled
        profile.healthKitSyncReminderDays = healthKitSyncReminderDays
        authState.updateProfile(profile)
        #if DEBUG
        DebugConfig.shared.log(.healthKit, "Saved HealthKit prefs: enabled=\(healthKitEnabled), reminderDays=\(healthKitSyncReminderDays)")
        #endif
    }

    private func requestHealthKitAccess() {
        Task {
            do {
                try await HealthKitService.shared.requestAuthorization()
                #if DEBUG
                DebugConfig.shared.log(.healthKit, "HealthKit authorization granted")
                #endif
            } catch {
                #if DEBUG
                DebugConfig.shared.log(.healthKit, "HealthKit authorization failed: \(error.localizedDescription)")
                #endif
                await MainActor.run {
                    healthKitEnabled = false
                    syncResultMessage = "HealthKit access denied. Please enable in Settings > Privacy > Health."
                    showSyncAlert = true
                }
            }
        }
    }

    private func performSync() {
        guard !isSyncing else { return }
        isSyncing = true

        Task {
            do {
                let lastSync = authState.currentUser?.lastHealthKitSync ?? store.events.map(\.date).min() ?? Date()
                let ignoredTypes = authState.currentUser?.ignoredWorkoutTypesForActivities ?? []
                let workoutMappings = authState.currentUser?.workoutTypeActivityMappings ?? [:]
                let result = try await HealthKitService.shared.syncNewWorkouts(
                    since: lastSync,
                    store: store,
                    ignoredTypes: ignoredTypes,
                    workoutMappings: workoutMappings
                )

                await MainActor.run {
                    // Update last sync timestamp
                    if var profile = authState.currentUser {
                        profile.lastHealthKitSync = Date()
                        authState.updateProfile(profile)
                    }

                    lastSyncResult = result
                    isSyncing = false
                    showSyncSummary = true
                    #if DEBUG
                    DebugConfig.shared.log(.healthKit, "Sync complete: added=\(result.addedCount), dupes=\(result.duplicateSkippedCount), skipped=\(result.skippedNoStayCount), linked=\(result.activitiesLinkedCount), unmatched=\(result.unmatchedWorkoutTypes.count)")
                    #endif
                }
            } catch {
                await MainActor.run {
                    syncResultMessage = "Sync failed: \(error.localizedDescription)"
                    showSyncAlert = true
                    isSyncing = false
                    #if DEBUG
                    DebugConfig.shared.log(.healthKit, "Sync failed: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }
}

// MARK: - Sync Summary Sheet

private struct SyncSummarySheet: View {
    let result: HealthKitService.SyncResult
    @ObservedObject var store: DataStore
    @ObservedObject var authState: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var mappingWorkoutType: ExerciseEntry.WorkoutType?
    @State private var resolvedTypes = Set<ExerciseEntry.WorkoutType>()

    var body: some View {
        NavigationStack {
            List {
                // Overall summary
                Section("Sync Results") {
                    summaryRow(icon: "plus.circle.fill", color: .green, label: "Workouts added", value: "\(result.addedCount)")
                    if result.duplicateSkippedCount > 0 {
                        summaryRow(icon: "arrow.triangle.2.circlepath", color: .secondary, label: "Already synced", value: "\(result.duplicateSkippedCount)")
                    }
                    if result.skippedNoStayCount > 0 {
                        summaryRow(icon: "calendar.badge.minus", color: .orange, label: "Skipped (no stay)", value: "\(result.skippedNoStayCount)")
                    }
                    if result.activitiesLinkedCount > 0 {
                        summaryRow(icon: "link.circle.fill", color: .blue, label: "Activities linked", value: "\(result.activitiesLinkedCount)")
                    }
                }

                // Unmatched workout types
                let unresolvedTypes = result.unmatchedWorkoutTypes.filter { !resolvedTypes.contains($0) }
                if !unresolvedTypes.isEmpty {
                    Section {
                        ForEach(unresolvedTypes, id: \.self) { workoutType in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: workoutType.sfSymbol)
                                        .foregroundColor(workoutType.color)
                                        .frame(width: 28)
                                    Text(workoutType.displayName)
                                        .fontWeight(.medium)
                                    Spacer()
                                }

                                if workoutType == .otherWorkout {
                                    Text("HealthKit couldn't identify this workout type.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack(spacing: 8) {
                                    Button("Add") {
                                        addActivity(for: workoutType)
                                        resolvedTypes.insert(workoutType)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)

                                    Button("Map to...") {
                                        mappingWorkoutType = workoutType
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button("Ignore") {
                                        ignoreWorkoutType(workoutType)
                                        resolvedTypes.insert(workoutType)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Unmatched Workout Types")
                    } footer: {
                        Text("Add creates a new activity. Map to links to an existing or new activity. Ignore remembers your choice for future syncs.")
                    }
                }
            }
            .navigationTitle("Sync Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $mappingWorkoutType) { workoutType in
                MapWorkoutToActivitySheet(
                    workoutType: workoutType,
                    store: store
                ) { activityName in
                    linkActivity(named: activityName, for: workoutType)
                    resolvedTypes.insert(workoutType)
                }
            }
        }
    }

    private func summaryRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }

    /// Add or find activity for a workout type and link to matching events
    private func addActivity(for workoutType: ExerciseEntry.WorkoutType) {
        linkActivity(named: workoutType.displayName, for: workoutType)
    }

    /// Link an activity by name to all events that have exercise entries of a given workout type.
    /// Reuses an existing activity if one with the same name exists (case-insensitive).
    /// Persists the mapping in UserProfile so future syncs auto-link without prompting.
    private func linkActivity(named activityName: String, for workoutType: ExerciseEntry.WorkoutType) {
        // Check if activity already exists (case-insensitive)
        let activity: Activity
        if let existing = store.activities.first(where: { $0.name.caseInsensitiveCompare(activityName) == .orderedSame }) {
            activity = existing
        } else {
            activity = Activity(name: activityName)
            store.addActivity(activity)
        }

        // Persist the mapping so future syncs auto-link this workout type
        if var profile = authState.currentUser {
            profile.workoutTypeActivityMappings[workoutType.rawValue] = activityName
            authState.updateProfile(profile)
        }

        // Link this activity to all events that have exercise entries of this type
        let entriesByDate = Dictionary(
            grouping: store.exerciseEntries.filter { $0.workoutType == workoutType },
            by: { $0.date.startOfDay }
        )

        var modified = false
        for (date, _) in entriesByDate {
            if let idx = store.events.firstIndex(where: { $0.date.startOfDay == date }) {
                if !store.events[idx].activityIDs.contains(activity.id) {
                    store.events[idx].activityIDs.append(activity.id)
                    modified = true
                }
            }
        }
        if modified {
            store.storeData()
        }

        #if DEBUG
        DebugConfig.shared.log(.healthKit, "Linked activity '\(activityName)' to \(entriesByDate.count) events for type '\(workoutType.displayName)', mapping saved")
        #endif
    }

    private func ignoreWorkoutType(_ workoutType: ExerciseEntry.WorkoutType) {
        guard var profile = authState.currentUser else { return }
        if !profile.ignoredWorkoutTypesForActivities.contains(workoutType.rawValue) {
            profile.ignoredWorkoutTypesForActivities.append(workoutType.rawValue)
            authState.updateProfile(profile)
        }
        #if DEBUG
        DebugConfig.shared.log(.healthKit, "Ignored workout type '\(workoutType.displayName)' for activity linking")
        #endif
    }
}

// MARK: - Map Workout to Activity Sheet

private struct MapWorkoutToActivitySheet: View {
    let workoutType: ExerciseEntry.WorkoutType
    @ObservedObject var store: DataStore
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newActivityName: String = ""

    var body: some View {
        NavigationStack {
            List {
                // Create new activity
                Section("Create New Activity") {
                    HStack {
                        TextField("Activity name", text: $newActivityName)
                            .textInputAutocapitalization(.words)
                        Button("Create") {
                            let trimmed = newActivityName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            onSelect(trimmed)
                            dismiss()
                        }
                        .disabled(newActivityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                // Pick from existing activities
                if !store.activities.isEmpty {
                    Section("Existing Activities") {
                        ForEach(store.activities.sorted { $0.name < $1.name }) { activity in
                            Button {
                                onSelect(activity.name)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(activity.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Map \"\(workoutType.displayName)\"")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PreferencesView()
    }
    .environmentObject(AuthState())
    .environmentObject(DataStore())
}
