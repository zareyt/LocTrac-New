import Foundation

struct Person: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    var displayName: String
    // If selected from Contacts, store the CNContact.identifier to re‑link later (optional)
    var contactIdentifier: String?
    
    init(id: String = UUID().uuidString, displayName: String, contactIdentifier: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.contactIdentifier = contactIdentifier
    }
}
