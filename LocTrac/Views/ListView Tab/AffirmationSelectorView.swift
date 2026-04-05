//
//  AffirmationSelectorView.swift
//  LocTrac
//
//  View for selecting multiple affirmations for events
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected affirmations preview
                if !selectedAffirmationIDs.isEmpty {
                    selectedAffirmationsSection
                }
                
                // Available affirmations
                List {
                    ForEach(filteredAffirmations) { affirmation in
                        AffirmationSelectionRow(
                            affirmation: affirmation,
                            isSelected: selectedAffirmationIDs.contains(affirmation.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleSelection(affirmation)
                        }
                    }
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
                }
            }
        }
    }
    
    private var selectedAffirmationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(selectedAffirmationIDs.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedAffirmations) { affirmation in
                        SelectedAffirmationChip(affirmation: affirmation) {
                            toggleSelection(affirmation)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
        .background(Color(.secondarySystemBackground))
    }
    
    private var selectedAffirmations: [Affirmation] {
        selectedAffirmationIDs.compactMap { id in
            store.affirmations.first(where: { $0.id == id })
        }
    }
    
    private func toggleSelection(_ affirmation: Affirmation) {
        if let index = selectedAffirmationIDs.firstIndex(of: affirmation.id) {
            selectedAffirmationIDs.remove(at: index)
        } else {
            selectedAffirmationIDs.append(affirmation.id)
        }
    }
}

struct AffirmationSelectionRow: View {
    let affirmation: Affirmation
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title3)
            
            // Category icon
            Image(systemName: affirmation.category.icon)
                .foregroundStyle(Color(affirmation.color).gradient)
                .frame(width: 24)
            
            // Text
            Text(affirmation.text)
                .font(.body)
                .lineLimit(2)
            
            Spacer()
            
            if affirmation.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SelectedAffirmationChip: View {
    let affirmation: Affirmation
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: affirmation.category.icon)
                .font(.caption2)
            
            Text(affirmation.text)
                .font(.caption)
                .lineLimit(1)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(affirmation.color).opacity(0.2))
        )
        .foregroundColor(Color(affirmation.color))
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
