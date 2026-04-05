//
//  RootView.swift
//  LocTrac
//
//  Root view that handles first launch wizard and main app navigation
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: DataStore
    
    var body: some View {
        // Display the actual main app view
        StartTabView()
            .environmentObject(store)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(DataStore())
    }
}
