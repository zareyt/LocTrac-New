//
//  ManagementView.swift
//  LocTrac
//
//  Unified management view for Activities, Affirmations, and future management screens
//

import SwiftUI

struct ManagementView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var debugConfig: DebugConfig

    enum ManagementTab: String, CaseIterable, Identifiable {
        case activities = "Activities"
        case affirmations = "Affirmations"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .activities: return "figure.walk"
            case .affirmations: return "sparkles"
            }
        }
        
        var color: Color {
            switch self {
            case .activities: return .green
            case .affirmations: return .blue
            }
        }
    }
    
    @State private var selectedTab: ManagementTab = .activities
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector with icons
                tabSelector
                
                // Content area
                TabView(selection: $selectedTab) {
                    ActivitiesManagementContent()
                        .tag(ManagementTab.activities)
                    
                    AffirmationsManagementContent()
                        .tag(ManagementTab.affirmations)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.large)
        }
        .debugViewName("ManagementView")
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ManagementTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.title2)
                            .foregroundStyle(selectedTab == tab ? tab.color.gradient : Color.secondary.gradient)
                        
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(selectedTab == tab ? tab.color.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.secondarySystemBackground))
        .overlay(
            // Selection indicator
            GeometryReader { geometry in
                let tabWidth = geometry.size.width / CGFloat(ManagementTab.allCases.count)
                let offset = tabWidth * CGFloat(ManagementTab.allCases.firstIndex(of: selectedTab) ?? 0)
                
                Rectangle()
                    .fill(selectedTab.color)
                    .frame(width: tabWidth, height: 3)
                    .offset(x: offset)
                    .animation(.spring(response: 0.3), value: selectedTab)
            }
            .frame(height: 3),
            alignment: .bottom
        )
    }
}

// MARK: - Activities Management Content

struct ActivitiesManagementContent: View {
    @EnvironmentObject var store: DataStore
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var editingActivity: Activity?

    var filteredActivities: [Activity] {
        if searchText.isEmpty {
            return store.activities.sorted { $0.name < $1.name }
        } else {
            return store.activities
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.name < $1.name }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Stats header
            statsHeader
            
            // Activities list
            if filteredActivities.isEmpty {
                emptyState
            } else {
                activitiesList
            }
        }
        .searchable(text: $searchText, prompt: "Search activities...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.green.gradient)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ActivityEditorView(activity: nil)
                .environmentObject(store)
        }
        .sheet(item: $editingActivity) { activity in
            ActivityEditorView(activity: activity)
                .environmentObject(store)
        }
    }
    
    private var statsHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                StatBadge(
                    value: "\(store.activities.count)",
                    label: "Total",
                    icon: "figure.walk",
                    color: .green
                )
                
                StatBadge(
                    value: "\(usageCount)",
                    label: "In Use",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }
    
    private var usageCount: Int {
        let usedActivityIDs = Set(store.events.flatMap { $0.activityIDs })
        return store.activities.filter { usedActivityIDs.contains($0.id) }.count
    }
    
    private var activitiesList: some View {
        List {
            ForEach(filteredActivities) { activity in
                ActivityManagementRow(activity: activity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingActivity = activity
                    }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.walk")
                .font(.system(size: 60))
                .foregroundStyle(.green.gradient)
            
            Text(searchText.isEmpty ? "No Activities Yet" : "No Results")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(searchText.isEmpty 
                ? "Create activities to track what you do at each location"
                : "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if searchText.isEmpty {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Create Activity", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ActivityManagementRow: View {
    @EnvironmentObject var store: DataStore
    let activity: Activity
    
    private var usageCount: Int {
        store.events.filter { $0.activityIDs.contains(activity.id) }.count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.title3)
                .foregroundStyle(.green.gradient)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.green.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                if usageCount > 0 {
                    Text("\(usageCount) event\(usageCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Not used yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ActivityEditorView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let activity: Activity?
    @State private var name: String = ""
    @State private var showDeleteConfirmation = false

    init(activity: Activity?) {
        self.activity = activity
        _name = State(initialValue: activity?.name ?? "")
    }

    /// Events that reference this activity, sorted by date descending
    private var referencingEvents: [Event] {
        guard let activity else { return [] }
        return store.events
            .filter { $0.activityIDs.contains(activity.id) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity Name") {
                    TextField("e.g., Skiing, Hiking, Dining", text: $name)
                }

                if let activity {
                    // Events referencing this activity
                    Section {
                        if referencingEvents.isEmpty {
                            Text("This activity is not used in any events.")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(referencingEvents) { event in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.date.utcMediumDateString)
                                            .font(.subheadline)
                                        Text(event.effectiveCity ?? event.location.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button {
                                        removeActivityFromEvent(activity: activity, event: event)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    } header: {
                        Text("Events (\(referencingEvents.count))")
                    } footer: {
                        if !referencingEvents.isEmpty {
                            Text("Tap the minus button to remove this activity from an individual event.")
                        }
                    }

                    // Delete activity section
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Activity", systemImage: "trash")
                                Spacer()
                            }
                        }
                    } footer: {
                        if !referencingEvents.isEmpty {
                            Text("Deleting will remove this activity and its references from all \(referencingEvents.count) event\(referencingEvents.count == 1 ? "" : "s").")
                        }
                    }
                }
            }
            .navigationTitle(activity == nil ? "New Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(activity == nil ? "Create" : "Save") {
                        saveActivity()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Activity", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let activity {
                        store.deleteActivity(activity)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let count = referencingEvents.count
                if count > 0 {
                    Text("Delete \"\(name)\"? This will remove it from \(count) event\(count == 1 ? "" : "s").")
                } else {
                    Text("Delete \"\(name)\"?")
                }
            }
        }
    }

    private func saveActivity() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let existing = activity {
            var updated = existing
            updated.name = trimmedName
            store.updateActivity(updated)
        } else {
            let newActivity = Activity(name: trimmedName)
            store.addActivity(newActivity)
        }

        dismiss()
    }

    private func removeActivityFromEvent(activity: Activity, event: Event) {
        var updated = event
        updated.activityIDs.removeAll { $0 == activity.id }
        store.update(updated)
    }
}

// MARK: - Affirmations Management Content

struct AffirmationsManagementContent: View {
    @EnvironmentObject var store: DataStore
    @State private var searchText = ""
    @State private var selectedCategory: Affirmation.Category? = nil
    @State private var showingAddSheet = false
    @State private var editingAffirmation: Affirmation?
    
    var filteredAffirmations: [Affirmation] {
        store.affirmations
            .filter { affirmation in
                let matchesSearch = searchText.isEmpty || affirmation.text.localizedCaseInsensitiveContains(searchText)
                let matchesCategory = selectedCategory == nil || affirmation.category == selectedCategory
                return matchesSearch && matchesCategory
            }
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite
                }
                return lhs.createdDate > rhs.createdDate
            }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Stats header
            statsHeader
            
            // Category filter
            categoryFilterSection
            
            // Affirmations list
            if filteredAffirmations.isEmpty {
                emptyState
            } else {
                affirmationsList
            }
        }
        .searchable(text: $searchText, prompt: "Search affirmations...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.blue.gradient)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ImprovedAffirmationEditorView(affirmation: nil)
                .environmentObject(store)
        }
        .sheet(item: $editingAffirmation) { affirmation in
            ImprovedAffirmationEditorView(affirmation: affirmation)
                .environmentObject(store)
        }
    }
    
    private var statsHeader: some View {
        HStack(spacing: 16) {
            StatBadge(
                value: "\(store.affirmations.count)",
                label: "Total",
                icon: "sparkles",
                color: .blue
            )
            
            StatBadge(
                value: "\(favoriteCount)",
                label: "Favorites",
                icon: "star.fill",
                color: .yellow
            )
            
            StatBadge(
                value: "\(usageCount)",
                label: "In Use",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private var favoriteCount: Int {
        store.affirmations.filter { $0.isFavorite }.count
    }
    
    private var usageCount: Int {
        let usedAffirmationIDs = Set(store.events.flatMap { $0.affirmationIDs })
        return store.affirmations.filter { usedAffirmationIDs.contains($0.id) }.count
    }
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                categoryPill(title: "All", icon: "sparkles", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                
                ForEach(Affirmation.Category.allCases, id: \.self) { category in
                    categoryPill(
                        title: category.rawValue.components(separatedBy: " ").first ?? category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category == selectedCategory ? nil : category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.tertiarySystemBackground))
    }
    
    private func categoryPill(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
        }
    }
    
    private var affirmationsList: some View {
        List {
            ForEach(filteredAffirmations) { affirmation in
                AffirmationManagementRow(affirmation: affirmation)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingAffirmation = affirmation
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    store.deleteAffirmation(filteredAffirmations[index])
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
            
            Text(searchText.isEmpty ? "No Affirmations Yet" : "No Results")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(searchText.isEmpty
                ? "Create affirmations to set positive intentions for your stays"
                : "Try a different search term or category")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if searchText.isEmpty {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Create Affirmation", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AffirmationManagementRow: View {
    @EnvironmentObject var store: DataStore
    let affirmation: Affirmation
    
    private var color: Color {
        // Convert string color name to SwiftUI Color
        switch affirmation.color {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "indigo": return .indigo
        case "teal": return .teal
        case "gray": return .gray
        default: return .blue
        }
    }
    
    private var usageCount: Int {
        store.events.filter { $0.affirmationIDs.contains(affirmation.id) }.count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: affirmation.category.icon)
                .font(.title3)
                .foregroundStyle(color.gradient)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(affirmation.text)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Text(affirmation.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if affirmation.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                    
                    if usageCount > 0 {
                        Text("• \(usageCount) event\(usageCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button {
                store.toggleFavorite(affirmation)
            } label: {
                Image(systemName: affirmation.isFavorite ? "star.fill" : "star")
                    .foregroundColor(affirmation.isFavorite ? .yellow : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper Views

struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Improved Affirmation Editor

struct ImprovedAffirmationEditorView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    let affirmation: Affirmation?
    
    @State private var text: String = ""
    @State private var selectedCategory: Affirmation.Category = .custom
    @State private var selectedColor: String = "blue"
    @State private var isFavorite: Bool = false
    
    private let colors = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "indigo", "teal"]
    
    init(affirmation: Affirmation?) {
        self.affirmation = affirmation
        _text = State(initialValue: affirmation?.text ?? "")
        _selectedCategory = State(initialValue: affirmation?.category ?? .custom)
        _selectedColor = State(initialValue: affirmation?.color ?? "blue")
        _isFavorite = State(initialValue: affirmation?.isFavorite ?? false)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Affirmation text
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                        .font(.body)
                } header: {
                    Text("Affirmation Text")
                } footer: {
                    Text("Write your affirmation in present tense, as if it's already true")
                }
                
                // Category selection with beautiful pills
                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Affirmation.Category.allCases, id: \.self) { category in
                                CategorySelectionPill(
                                    category: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                    selectedColor = category.defaultColor
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                // Color picker
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(colors, id: \.self) { color in
                                ColorCircle(
                                    colorName: color,
                                    isSelected: selectedColor == color
                                ) {
                                    selectedColor = color
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Color")
                } footer: {
                    Text("Choose a color for visual organization")
                }
                
                // Favorite toggle
                Section {
                    Toggle(isOn: $isFavorite) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Mark as Favorite")
                        }
                    }
                } footer: {
                    Text("Favorites appear at the top of your list")
                }
                
                // Preview
                Section("Preview") {
                    HStack(spacing: 12) {
                        Image(systemName: selectedCategory.icon)
                            .font(.title2)
                            .foregroundStyle(Color(selectedColor).gradient)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color(selectedColor).opacity(0.15))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text.isEmpty ? "Your affirmation text" : text)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(text.isEmpty ? .secondary : .primary)
                            
                            HStack(spacing: 4) {
                                Text(selectedCategory.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if isFavorite {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(affirmation == nil ? "New Affirmation" : "Edit Affirmation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(affirmation == nil ? "Create" : "Save") {
                        saveAffirmation()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveAffirmation() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        if let existing = affirmation {
            var updated = existing
            updated.text = trimmedText
            updated.category = selectedCategory
            updated.color = selectedColor
            updated.isFavorite = isFavorite
            store.updateAffirmation(updated)
        } else {
            let newAffirmation = Affirmation(
                text: trimmedText,
                category: selectedCategory,
                color: selectedColor,
                isFavorite: isFavorite
            )
            store.addAffirmation(newAffirmation)
        }
        
        dismiss()
    }
}

struct CategorySelectionPill: View {
    let category: Affirmation.Category
    let isSelected: Bool
    let action: () -> Void
    
    private var color: Color {
        switch category.defaultColor {
        case "green": return .green
        case "yellow": return .yellow
        case "pink": return .pink
        case "orange": return .orange
        case "purple": return .purple
        case "blue": return .blue
        case "indigo": return .indigo
        case "gray": return .gray
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isSelected ? color : color.opacity(0.15))
                    )
                
                Text(category.rawValue.components(separatedBy: " ").first ?? category.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? color : .primary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ColorCircle: View {
    let colorName: String
    let isSelected: Bool
    let action: () -> Void
    
    private var color: Color {
        switch colorName {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "indigo": return .indigo
        case "teal": return .teal
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.gradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .opacity(isSelected ? 1 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(color, lineWidth: 2)
                )
                .shadow(color: color.opacity(0.4), radius: isSelected ? 8 : 4)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct ManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ManagementView()
            .environmentObject(DataStore(preview: true))
    }
}
