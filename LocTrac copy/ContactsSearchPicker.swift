import SwiftUI
import Contacts

struct ContactsSearchPicker: View {
    @Environment(\.dismiss) private var dismiss

    // Results back to the caller
    let onDone: ([CNContact]) -> Void

    @State private var allContacts: [CNContact] = []
    @State private var filtered: [CNContact] = []
    @State private var query: String = ""
    @State private var selection = Set<String>() // CNContact.identifier
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Contacts")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add") {
                            let selectedContacts = allContacts.filter { selection.contains($0.identifier) }
                            onDone(selectedContacts)
                            dismiss()
                        }
                        .disabled(selection.isEmpty)
                    }
                }
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search contacts")
                .onChange(of: query) { _, newQuery in
                    applyFilter(query: newQuery)
                }
                .task {
                    await loadContacts()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            AnyView(
                VStack {
                    Spacer()
                    ProgressView("Loading contacts…")
                    Spacer()
                }
                .padding()
            )
        } else if let errorMessage {
            AnyView(
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .imageScale(.large)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
            )
        } else if filtered.isEmpty {
            AnyView(
                VStack {
                    Spacer()
                    Text(query.isEmpty ? "No contacts found." : "No matches for “\(query)”.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
            )
        } else {
            AnyView(
                List(filtered, id: \.identifier) { contact in
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.accentColor)
                        Text(displayName(for: contact))
                        Spacer()
                        if selection.contains(contact.identifier) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(contact) }
                }
            )
        }
    }

    private func displayName(for contact: CNContact) -> String {
        CNContactFormatter.string(from: contact, style: .fullName) ?? "Unknown"
    }

    private func toggle(_ contact: CNContact) {
        if selection.contains(contact.identifier) {
            selection.remove(contact.identifier)
        } else {
            selection.insert(contact.identifier)
        }
    }

    @MainActor
    private func applyFilter(query: String) {
        guard !query.isEmpty else {
            filtered = allContacts
            return
        }
        let lower = query.lowercased()
        filtered = allContacts.filter { c in
            let name = displayName(for: c).lowercased()
            if name.contains(lower) { return true }
            if c.organizationName.lowercased().contains(lower) { return true }
            return false
        }
    }

    private func loadContacts() async {
        loading = true
        defer { loading = false }
        do {
            // Request access first; we only need to throw if denied, no value needed
            _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                let store = CNContactStore()
                store.requestAccess(for: .contacts) { granted, err in
                    if let err { cont.resume(throwing: err); return }
                    if !granted {
                        cont.resume(throwing: NSError(domain: "Contacts", code: 1, userInfo: [
                            NSLocalizedDescriptionKey: "Access to Contacts was denied. You can enable it in Settings."
                        ]))
                        return
                    }
                    cont.resume()
                }
            }

            // Do the heavy work off the main actor explicitly; return only contacts
            let contacts: [CNContact] = try await Task.detached(priority: .userInitiated) { () -> [CNContact] in
                let store = CNContactStore()
                let keys: [CNKeyDescriptor] = [
                    CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                    CNContactIdentifierKey as CNKeyDescriptor,
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor,
                    CNContactOrganizationNameKey as CNKeyDescriptor
                ]
                let req = CNContactFetchRequest(keysToFetch: keys)
                var results: [CNContact] = []
                try store.enumerateContacts(with: req) { contact, _ in
                    results.append(contact)
                }
                // Precompute display names for sorting off-main
                let nameStrings = results.map { CNContactFormatter.string(from: $0, style: .fullName) ?? "" }
                // Sort using the precomputed names
                let sortedIndices = nameStrings.indices.sorted { nameStrings[$0] < nameStrings[$1] }
                let sortedContacts = sortedIndices.map { results[$0] }
                return sortedContacts
            }.value

            await MainActor.run {
                self.allContacts = contacts
                self.filtered = contacts
            }
        } catch {
            await MainActor.run {
                self.errorMessage = (error as NSError).localizedDescription
            }
        }
    }
}
