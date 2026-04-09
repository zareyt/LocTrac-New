//
//  AffirmationEditorView.swift
//  LocTrac
//
//  View for creating and editing affirmations with beautiful category pill selection
//

import SwiftUI

struct AffirmationEditorView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    let affirmation: Affirmation?
    
    @State private var text: String = ""
    @State private var selectedCategory: Affirmation.Category = .custom
    @State private var selectedColorValue: Color = .blue
    @State private var isFavorite: Bool = false
    
    init(affirmation: Affirmation?) {
        self.affirmation = affirmation
        _text = State(initialValue: affirmation?.text ?? "")
        _selectedCategory = State(initialValue: affirmation?.category ?? .custom)
        _selectedColorValue = State(initialValue: stringToColor(affirmation?.color ?? "blue"))
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
                                    selectedColorValue = stringToColor(category.defaultColor)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                // Native iOS Color Picker (same as Manage Locations)
                Section {
                    ColorPicker("Color", selection: $selectedColorValue, supportsOpacity: false)
                    
                    HStack {
                        Text("Preview")
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedColorValue)
                            .frame(width: 30, height: 30)
                    }
                } header: {
                    Text("Theme Color")
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
                            .foregroundStyle(selectedColorValue.gradient)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(selectedColorValue.opacity(0.15))
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
        
        let colorString = colorToString(selectedColorValue)
        
        if let existing = affirmation {
            var updated = existing
            updated.text = trimmedText
            updated.category = selectedCategory
            updated.color = colorString
            updated.isFavorite = isFavorite
            store.updateAffirmation(updated)
        } else {
            let newAffirmation = Affirmation(
                text: trimmedText,
                category: selectedCategory,
                color: colorString,
                isFavorite: isFavorite
            )
            store.addAffirmation(newAffirmation)
        }
        
        dismiss()
    }
}

// MARK: - Color Conversion Helpers

private func stringToColor(_ string: String) -> Color {
    switch string {
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

private func colorToString(_ color: Color) -> String {
    // Try to match the color to one of our standard colors
    switch color {
    case .purple: return "purple"
    case .pink: return "pink"
    case .red: return "red"
    case .orange: return "orange"
    case .yellow: return "yellow"
    case .green: return "green"
    case .indigo: return "indigo"
    case .teal: return "teal"
    case .gray: return "gray"
    default: return "blue"
    }
}

// MARK: - Preview

struct AffirmationEditorView_Previews: PreviewProvider {
    static var previews: some View {
        AffirmationEditorView(affirmation: nil)
            .environmentObject(DataStore(preview: true))
    }
}
