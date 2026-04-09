//
//  AffirmationsLibraryView.swift
//  LocTrac
//
//  Main view for managing user's affirmations library
//

import SwiftUI

struct AffirmationsLibraryView: View {
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
                // Favorites first, then by creation date
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite
                }
                return lhs.createdDate > rhs.createdDate
            }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter pills
                categoryFilterSection
                
                // Affirmations list
                if filteredAffirmations.isEmpty {
                    emptyState
                } else {
                    affirmationsList
                }
            }
            .navigationTitle("My Affirmations")
            .searchable(text: $searchText, prompt: "Search affirmations...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AffirmationEditorView(affirmation: nil)
                    .environmentObject(store)
            }
            .sheet(item: $editingAffirmation) { affirmation in
                AffirmationEditorView(affirmation: affirmation)
                    .environmentObject(store)
            }
        }
    }
    
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
    
    private var affirmationsList: some View {
        List {
            ForEach(filteredAffirmations) { affirmation in
                AffirmationRow(affirmation: affirmation)
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
            
            Text("No Affirmations Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Create your first affirmation to start manifesting positive energy")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showingAddSheet = true
            } label: {
                Label("Create Affirmation", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AffirmationRow: View {
    @EnvironmentObject var store: DataStore
    let affirmation: Affirmation
    
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
            // Category icon
            Image(systemName: affirmation.category.icon)
                .font(.title3)
                .foregroundStyle(color.gradient)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
            
            // Affirmation text
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
                }
            }
            
            Spacer()
            
            // Favorite button
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

// MARK: - Preview

struct AffirmationsLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        AffirmationsLibraryView()
            .environmentObject(DataStore(preview: true))
    }
}
