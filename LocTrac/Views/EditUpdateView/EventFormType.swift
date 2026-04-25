//
// Created for UICalendarView_SwiftUI
// by Stewart Lynch on 2022-06-29
// Using Swift 5.0
//
// Follow me on Twitter: @StewartLynch
// Subscribe on YouTube: https://youTube.com/StewartLynch
//

import SwiftUI

enum EventFormType: Identifiable, View, Hashable {
    case new(DateComponents)
    case newWithViewModel(EventFormViewModel)
    case update(Event)

    var id: String {
        switch self {
        case .new:
            return "new"
        case .newWithViewModel:
            return "newWithViewModel"
        case .update(let event):
            return event.id
        }
    }

    // Hashable conformance
    static func == (lhs: EventFormType, rhs: EventFormType) -> Bool {
        switch (lhs, rhs) {
        case (.new(let l), .new(let r)):
            return l.year == r.year && l.month == r.month && l.day == r.day
        case (.newWithViewModel, .newWithViewModel):
            return true
        case (.update(let le), .update(let re)):
            return le.id == re.id
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .new(let comps):
            hasher.combine("new")
            hasher.combine(comps.year)
            hasher.combine(comps.month)
            hasher.combine(comps.day)
        case .newWithViewModel:
            hasher.combine("newWithViewModel")
        case .update(let event):
            hasher.combine("update")
            hasher.combine(event.id)
        }
    }

    var body: some View {
        switch self {
        case .new(let dateComponents):
            let calendar = Calendar(identifier: .gregorian)
            let localDate = calendar.date(from: dateComponents)!
            let GMT = TimeZone(secondsFromGMT: 0)!
            let GMTDateComponents = calendar.dateComponents(in: GMT, from: localDate)
            let GMTDate = calendar.date(from: GMTDateComponents)!
            return ModernEventFormView(viewModel: EventFormViewModel(dateSelected: GMTDate.startOfDay))
        case .newWithViewModel(let viewModel):
            return ModernEventFormView(viewModel: viewModel)
        case .update(let event):
            return ModernEventFormView(viewModel: EventFormViewModel(event))
        }
    }
}
