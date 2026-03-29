//
// Created for UICalendarView_SwiftUI
// by Stewart Lynch on 2022-06-29
// Using Swift 5.0
//
// Follow me on Twitter: @StewartLynch
// Subscribe on YouTube: https://youTube.com/StewartLynch
//

import SwiftUI

struct EventsListView: View {
    @EnvironmentObject var store: DataStore
    @State private var formType: EventFormType?
    
    var body: some View {
        NavigationStack {
            List {
//                ForEach(store.locations) {
//                    location in
//                    Section (header: Text(location.name + " " + location.icon)) {
//                        //  Filter by location name
//                        ForEach(store.events.filter({ $0.location.id == location.id })) { event in
//
//                            ListViewRow(event: event, formType: $formType)
//                                .swipeActions {
//                                    Button(role: .destructive) {
//                                        store.delete(event)
//                                    } label: {
//                                        Image(systemName: "trash")
//                                    }
//                                }
//                        }
//                    }
//                }
//
//            }
//            .navigationTitle("Location Stays")
//            .sheet(item: $formType) { formType in
//                switch formType {
//                case .new:
//                    NavigationView {
//                        EventFormView(viewModel: EventFormViewModel(), formType: .new)
//                    }
//                case .update(let event):
//                    NavigationView {
//                        EventFormView(viewModel: EventFormViewModel(event: event), formType: .update(event))
//                    }
//                }
//            }
//
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button {
//                        formType = .new
//                    } label: {
//                        Image(systemName: "plus.circle.fill")
//                            .imageScale(.medium)
//                    }
//                }
            }
        }
    }
}

struct EventsListView_Previews: PreviewProvider {
    static var previews: some View {
        EventsListView()
            .environmentObject(DataStore(preview: true))
    }
}
