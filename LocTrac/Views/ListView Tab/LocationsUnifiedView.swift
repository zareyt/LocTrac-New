//
//  LocationsUnifiedView.swift
//  LocTrac
//
//  Created on 3/22/26.
//  Unified view combining map and list with draggable sheet
//

import SwiftUI

struct LocationsUnifiedView: View {
    @EnvironmentObject var store: DataStore
    @StateObject private var mapVM = LocationsMapViewModel()
    @State private var lformType: LocationFormType?
    
    var body: some View {
        // Just the map - no List View button
        mapLayer
            .onAppear {
                // Initialize the map view model with the store
                mapVM.setStore(store)
            }
            .onChange(of: store.locations) { oldValue, newValue in
                // Refresh map when locations change
                mapVM.refreshLocations()
            }
            .sheet(item: $lformType) { $0 }
    }
    
    // MARK: - Map Layer
    
    private var mapLayer: some View {
        LocationsView()
            .environmentObject(mapVM)
            .environmentObject(store)
    }
}

// MARK: - Preview

struct LocationsUnifiedView_Previews: PreviewProvider {
    static var previews: some View {
        LocationsUnifiedView()
            .environmentObject(DataStore(preview: true))
    }
}
