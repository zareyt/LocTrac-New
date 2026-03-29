//
// LocTrac
// by Tim Arey on 2023-02-22
// Using Swift 5.0
//
//
// Based from UICalendar example https://youTube.com/StewartLynch
//

import SwiftUI

@main
struct AppEntry: App {
    var store = DataStore()
   
    var body: some Scene {
        WindowGroup {
            StartTabView()
                .environmentObject(store)
        }
    }
}

