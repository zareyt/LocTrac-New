//
//  LocationsListView.swift
//  Locations
//
//  Created by Tim Arey on 2/1/23.
//

import SwiftUI

struct LocationsListView: View {
    @EnvironmentObject var store: DataStore
    @State private var lformType: LocationFormType?
    @State var expandedSections = Set<Int>()
    
    var body: some View {
        List {
            ForEach(store.locations.sorted { $0.name < $1.name }) { location in
                let index = store.locations.firstIndex(where: { $0.id == location.id }) ?? 0
                DisclosureGroup(location.name + " ",
                    isExpanded: Binding(
                        get: { self.expandedSections.contains(index) },
                        set: { if $0 { self.expandedSections.insert(index) } else { self.expandedSections.remove(index) } }
                    )
                ) {
                    LocationLiistViewRow(location: location, lformType: $lformType)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(location)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle("Tracking Locations")
        .sheet(item: $lformType) { $0 }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    lformType = .new
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.medium)
                }
            }
        }
    }
}


struct LocationsListView_Previews: PreviewProvider {
    static var previews: some View {
        LocationsListView()
            .environmentObject(DataStore())
    }
}
