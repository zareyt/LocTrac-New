import Foundation

struct PendingTripItem: Identifiable {
    let id = UUID()
    let trip: Trip
    let fromEvent: Event
    let toEvent: Event
}
