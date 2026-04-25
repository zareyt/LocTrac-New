import Foundation
import SwiftUI

/// User-manageable event type with customizable appearance.
/// Stored in DataStore and persisted in backup.json.
struct EventTypeItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String        // Raw value stored in Event.eventType (e.g. "stay", "camping")
    var displayName: String // User-facing name (e.g. "Stay", "Camping")
    var sfSymbol: String    // SF Symbol name (e.g. "bed.double.fill")
    var colorName: String   // Named color string (e.g. "red", "blue")
    var isBuiltIn: Bool     // true for the 6 default types — prevents deletion

    init(id: String = UUID().uuidString,
         name: String,
         displayName: String,
         sfSymbol: String,
         colorName: String,
         isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.sfSymbol = sfSymbol
        self.colorName = colorName
        self.isBuiltIn = isBuiltIn
    }

    /// Resolve colorName to a SwiftUI Color
    var color: Color {
        Self.colorFromName(colorName)
    }

    // MARK: - Color Name Mapping

    /// All available color names for the picker
    static let availableColors: [(name: String, color: Color)] = [
        ("red", .red),
        ("blue", .blue),
        ("green", .green),
        ("purple", .purple),
        ("orange", .orange),
        ("brown", .brown),
        ("pink", .pink),
        ("teal", .teal),
        ("indigo", .indigo),
        ("mint", .mint),
        ("cyan", .cyan),
        ("yellow", .yellow),
        ("gray", .gray),
    ]

    static func colorFromName(_ name: String) -> Color {
        availableColors.first(where: { $0.name == name })?.color ?? .gray
    }

    // MARK: - Default Event Types

    /// The 6 built-in event types seeded on first launch
    static let defaults: [EventTypeItem] = [
        EventTypeItem(name: "stay", displayName: "Stay", sfSymbol: "bed.double.fill", colorName: "red", isBuiltIn: true),
        EventTypeItem(name: "host", displayName: "Host", sfSymbol: "house.fill", colorName: "blue", isBuiltIn: true),
        EventTypeItem(name: "vacation", displayName: "Vacation", sfSymbol: "airplane", colorName: "green", isBuiltIn: true),
        EventTypeItem(name: "family", displayName: "Family", sfSymbol: "figure.2.and.child.holdinghands", colorName: "purple", isBuiltIn: true),
        EventTypeItem(name: "business", displayName: "Business", sfSymbol: "briefcase.fill", colorName: "brown", isBuiltIn: true),
        EventTypeItem(name: "unspecified", displayName: "Unspecified", sfSymbol: "questionmark.circle", colorName: "gray", isBuiltIn: true),
    ]
}
