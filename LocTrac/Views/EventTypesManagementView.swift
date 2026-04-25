import SwiftUI

struct EventTypesManagementView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var debugConfig: DebugConfig
    @Environment(\.dismiss) var dismiss
    @State private var showingAddSheet = false
    @State private var editingItem: EventTypeItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.eventTypes) { item in
                        eventTypeRow(item)
                    }
                    .onDelete(perform: deleteItems)
                } footer: {
                    Text("Built-in types cannot be deleted. Custom types in use will be reset to Unspecified if deleted.")
                        .font(.caption)
                }

                Section {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Event Type", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Manage Event Types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                EventTypeFormView(mode: .add) { newItem in
                    store.addEventType(newItem)
                }
                .environmentObject(store)
            }
            .sheet(item: $editingItem) { item in
                EventTypeFormView(mode: .edit(item)) { updatedItem in
                    store.updateEventType(updatedItem)
                }
                .environmentObject(store)
            }
        }
        .debugViewName("EventTypesManagementView")
    }

    @ViewBuilder
    private func eventTypeRow(_ item: EventTypeItem) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: item.sfSymbol)
                        .font(.body)
                        .foregroundStyle(item.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.displayName)
                            .font(.body)
                            .foregroundColor(.primary)
                        if item.isBuiltIn {
                            Text("Built-in")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(Capsule())
                        }
                    }
                    Text(usageCount(for: item))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func usageCount(for item: EventTypeItem) -> String {
        let count = store.events.filter { $0.eventType == item.name }.count
        return "\(count) event\(count == 1 ? "" : "s")"
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = store.eventTypes[index]
            if !item.isBuiltIn {
                store.deleteEventType(item)
            }
        }
    }
}

// MARK: - Event Type Form (Add / Edit)

struct EventTypeFormView: View {
    enum Mode: Identifiable {
        case add
        case edit(EventTypeItem)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let item): return item.id
            }
        }
    }

    let mode: Mode
    let onSave: (EventTypeItem) -> Void

    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var displayName: String = ""
    @State private var selectedSymbol: String = "star.fill"
    @State private var selectedColor: String = "blue"
    @State private var isBuiltIn: Bool = false
    @State private var existingId: String = ""

    // Popular SF Symbols for event types
    private let symbolOptions: [(name: String, symbol: String)] = [
        ("Bed", "bed.double.fill"),
        ("House", "house.fill"),
        ("Airplane", "airplane"),
        ("Family", "figure.2.and.child.holdinghands"),
        ("Briefcase", "briefcase.fill"),
        ("Question", "questionmark.circle"),
        ("Car", "car.fill"),
        ("Train", "tram.fill"),
        ("Tent", "tent.fill"),
        ("Star", "star.fill"),
        ("Heart", "heart.fill"),
        ("Flag", "flag.fill"),
        ("Camera", "camera.fill"),
        ("Music", "music.note"),
        ("Fork & Knife", "fork.knife"),
        ("Cart", "cart.fill"),
        ("Book", "book.fill"),
        ("Graduation", "graduationcap.fill"),
        ("Medical", "cross.case.fill"),
        ("Gift", "gift.fill"),
        ("Person", "person.fill"),
        ("Globe", "globe"),
        ("Mountain", "mountain.2.fill"),
        ("Beach", "beach.umbrella.fill"),
    ]

    private var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section {
                    TextField("Display Name", text: $displayName)
                        .onChange(of: displayName) { _, newValue in
                            // Auto-generate internal name from display name (for new types only)
                            if !isEditing {
                                name = newValue.lowercased().replacingOccurrences(of: " ", with: "_")
                            }
                        }
                } header: {
                    Label("Name", systemImage: "textformat")
                } footer: {
                    if isEditing && isBuiltIn {
                        Text("Built-in type — name cannot be changed, but you can customize the icon and color.")
                            .font(.caption)
                    }
                }

                // Icon Section
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(symbolOptions, id: \.symbol) { option in
                            Button {
                                selectedSymbol = option.symbol
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedSymbol == option.symbol ? EventTypeItem.colorFromName(selectedColor).opacity(0.2) : Color(.tertiarySystemFill))
                                        .frame(height: 44)
                                    Image(systemName: option.symbol)
                                        .font(.body)
                                        .foregroundStyle(selectedSymbol == option.symbol ? EventTypeItem.colorFromName(selectedColor) : .secondary)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedSymbol == option.symbol ? EventTypeItem.colorFromName(selectedColor) : .clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Icon", systemImage: "star.circle")
                }

                // Color Section
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(EventTypeItem.availableColors, id: \.name) { option in
                            Button {
                                selectedColor = option.name
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(option.color.gradient)
                                        .frame(width: 36, height: 36)
                                    if selectedColor == option.name {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Color", systemImage: "paintpalette")
                }

                // Preview Section
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(EventTypeItem.colorFromName(selectedColor).opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: selectedSymbol)
                                .font(.title3)
                                .foregroundStyle(EventTypeItem.colorFromName(selectedColor))
                        }
                        VStack(alignment: .leading) {
                            Text(displayName.isEmpty ? "Event Type" : displayName)
                                .font(.headline)
                            Text("Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        // Badge preview
                        HStack(spacing: 6) {
                            Image(systemName: selectedSymbol)
                                .font(.caption)
                                .foregroundColor(.white)
                            Text(displayName.isEmpty ? "Type" : displayName)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(EventTypeItem.colorFromName(selectedColor).gradient)
                        .clipShape(Capsule())
                    }
                } header: {
                    Label("Preview", systemImage: "eye")
                }
            }
            .navigationTitle(isEditing ? "Edit Event Type" : "New Event Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEventType()
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                if case .edit(let item) = mode {
                    existingId = item.id
                    name = item.name
                    displayName = item.displayName
                    selectedSymbol = item.sfSymbol
                    selectedColor = item.colorName
                    isBuiltIn = item.isBuiltIn
                }
            }
        }
    }

    private func saveEventType() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let internalName: String
        if isEditing {
            internalName = name // Keep existing internal name for edits
        } else {
            internalName = trimmedName.lowercased().replacingOccurrences(of: " ", with: "_")
        }

        let item = EventTypeItem(
            id: isEditing ? existingId : UUID().uuidString,
            name: internalName,
            displayName: trimmedName,
            sfSymbol: selectedSymbol,
            colorName: selectedColor,
            isBuiltIn: isBuiltIn
        )
        onSave(item)
    }
}
