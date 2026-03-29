//
//  RootView.swift
//  LocTrac
//
//  Root view that handles first launch wizard and main app navigation
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: DataStore
    @State private var showWizard = false
    
    var body: some View {
        Group {
            // Your main app view goes here (replace with actual main view)
            // For example: StartTabView() or whatever your main navigation is
            Text("Main App Content")
                .onAppear {
                    checkFirstLaunch()
                }
        }
        .sheet(isPresented: $showWizard) {
            FirstLaunchWizard()
                .environmentObject(store)
        }
    }
    
    private func checkFirstLaunch() {
        // Check if wizard needs to be shown
        if store.isFirstLaunch {
            showWizard = true
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(DataStore())
    }
}
