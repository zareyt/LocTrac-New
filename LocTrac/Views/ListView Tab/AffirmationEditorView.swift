//
//  AffirmationEditorView.swift
//  LocTrac
//
//  View for creating and editing affirmations
//

import SwiftUI

struct AffirmationEditorView: View {
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
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                        .font(.body)
                } header: {
                    Text("Affirmation Text")
                } footer: {
                    Text("Write your affirmation in present tense, as if it's already true")
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(Affirmation.Category.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: selectedCategory) { _, newValue in
                        selectedColor = newValue.defaultColor
                    }
                }
                
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(colors, id: \.self) { color in
                                colorCircle(color)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Toggle(isOn: $isFavorite) {
                        Label("Mark as Favorite", systemImage: "star.fill")
                    }
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
    
    private func colorCircle(_ colorName: String) -> some View {
        Button {
            selectedColor = colorName
        } label: {
            Circle()
                .fill(Color(colorName).gradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .opacity(selectedColor == colorName ? 1 : 0)
                )
                .shadow(color: Color(colorName).opacity(0.4), radius: 4)
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

// MARK: - Preview

struct AffirmationEditorView_Previews: PreviewProvider {
    static var previews: some View {
        AffirmationEditorView(affirmation: nil)
            .environmentObject(DataStore(preview: true))
    }
}
