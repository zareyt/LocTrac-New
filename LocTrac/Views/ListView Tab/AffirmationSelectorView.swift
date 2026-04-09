//
//  AffirmationSelectorView.swift
//  LocTrac
//
//  View for selecting multiple affirmations for events
//  Enhanced with category filtering and full text display
//

import SwiftUI

struct AffirmationSelectorView: View {
    @EnvironmentObject var store: DataStore
    @Binding var selectedAffirmationIDs: [String]
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedCategory: Affirmation.Category? = nil
    
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
    
    var selectedAffirmations: [Affirmation] {
        selectedAffirmationIDs.compactMap { id in
            store.affirmations.first(where: { $0.id == id })
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter pills (same as Manage Affirmations)
                categoryFilterSection
                
                // Selected count header
                if !selectedAffirmationIDs.isEmpty {
                    selectedCountHeader
                }
                
                // Affirmations list
                if filteredAffirmations.isEmpty {
                    emptyState
                } else {
                    affirmationsList
                }
            }
            .navigationTitle("Select Affirmations")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search affirmations...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "All" button
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
        .background(Color(.secondarySystemBackground))
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
                    .fill(isSelected ? Color.blue : Color(.tertiarySystemBackground))
            )
        }
    }
    
    private var selectedCountHeader: some View {
        HStack {
            Text("\(selectedAffirmationIDs.count) Selected")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            Spacer()
            
            if !selectedAffirmationIDs.isEmpty {
                Button("Clear All") {
                    withAnimation {
                        selectedAffirmationIDs.removeAll()
                    }
                }
                .font(.subheadline)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
    }
    
    private var affirmationsList: some View {
        List {
            ForEach(filteredAffirmations) { affirmation in
                ImprovedAffirmationSelectionRow(
                    affirmation: affirmation,
                    isSelected: selectedAffirmationIDs.contains(affirmation.id)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(affirmation)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: searchText.isEmpty ? "sparkles" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
            
            Text(searchText.isEmpty ? "No Affirmations Yet" : "No Results")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(searchText.isEmpty
                ? "Create affirmations in Manage Activities & Affirmations"
                : "Try a different search term or category")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func toggleSelection(_ affirmation: Affirmation) {
        withAnimation(.spring(response: 0.3)) {
            if let index = selectedAffirmationIDs.firstIndex(of: affirmation.id) {
                selectedAffirmationIDs.remove(at: index)
            } else {
                selectedAffirmationIDs.append(affirmation.id)
            }
        }
    }
}

// MARK: - Improved Selection Row

struct ImprovedAffirmationSelectionRow: View {
    let affirmation: Affirmation
    let isSelected: Bool
    
    private var color: Color {
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator with animation
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title2)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isSelected)
            
            // Category icon with colored background (same as Manage Affirmations)
            Image(systemName: affirmation.category.icon)
                .font(.title3)
                .foregroundStyle(color.gradient)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
            
            // Text content with full display
            VStack(alignment: .leading, spacing: 4) {
                Text(affirmation.text)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(nil) // Show full text, no truncation
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 4) {
                    Text(affirmation.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if affirmation.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(isSelected ? color.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct AffirmationSelectorView_Previews: PreviewProvider {
    @State static var selectedIDs: [String] = []
    
    static var previews: some View {
        AffirmationSelectorView(selectedAffirmationIDs: $selectedIDs)
            .environmentObject(DataStore(preview: true))
    }
}
