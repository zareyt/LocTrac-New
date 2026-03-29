import SwiftUI

struct ActivitiesMaintenanceView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var newName: String = ""
    @State private var editing: Activity?
    @State private var editedName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Add Activity")) {
                    HStack {
                        TextField("Activity name", text: $newName)
                            .textInputAutocapitalization(.words)
                        Button {
                            addNew()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(!canAdd(name: newName))
                    }
                }
                
                Section(header: Text("All Activities")) {
                    if store.activities.isEmpty {
                        Text("No activities. Add one above.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(store.activities) { activity in
                            if editing?.id == activity.id {
                                HStack {
                                    TextField("Name", text: $editedName)
                                        .textInputAutocapitalization(.words)
                                    Button {
                                        saveEdit()
                                    } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    .disabled(!canAdd(name: editedName, excludingID: activity.id))
                                    
                                    Button(role: .cancel) {
                                        cancelEdit()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                HStack {
                                    Text(activity.name)
                                    Spacer()
                                    Button {
                                        startEdit(activity)
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Manage Activities")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func canAdd(name: String, excludingID: String? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let exists = store.activities.contains { act in
            if let excludingID, act.id == excludingID { return false }
            return act.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        return !exists
    }
    
    private func addNew() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAdd(name: trimmed) else { return }
        store.addActivity(Activity(name: trimmed))
        newName = ""
    }
    
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let act = store.activities[index]
            store.deleteActivity(act)
        }
    }
    
    private func startEdit(_ activity: Activity) {
        editing = activity
        editedName = activity.name
    }
    
    private func saveEdit() {
        guard var act = editing else { return }
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAdd(name: trimmed, excludingID: act.id) else { return }
        act.name = trimmed
        store.updateActivity(act)
        editing = nil
        editedName = ""
    }
    
    private func cancelEdit() {
        editing = nil
        editedName = ""
    }
}

struct ActivitiesMaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        ActivitiesMaintenanceView()
            .environmentObject(DataStore())
    }
}

