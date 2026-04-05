//
// Author Tim Arey
//

import SwiftUI

struct StartTabView: View {
    @EnvironmentObject var store: DataStore
    @State private var selection: Int = 0 // Start on Home tab
    @State private var showAbout: Bool = false
    @State private var lformType: LocationFormType? // For adding/updating locations
    @State private var showActivitiesManager: Bool = false
    @State private var showBackupExport: Bool = false // For backup/import
    @State private var showFirstLaunchWizard: Bool = false // For first launch wizard
    @State private var showTripsManagement: Bool = false // For trips management
    @State private var showImportGolfshot: Bool = false // For Golfshot CSV import
    @State private var showLocationsManagement: Bool = false // For managing locations
    @State private var showTravelHistory: Bool = false // For comprehensive travel history
    @State private var showCountryUpdater: Bool = false // For updating event countries
    @State private var showLocationSync: Bool = false // For syncing event coordinates
    
    // Drives TripConfirmationView sheet
    @State private var pendingItem: PendingTripItem?
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                // Home tab
                HomeView(
                    onAddEvent: { selection = 1 },
                    onAddLocation: { lformType = .new },
                    onShowOtherCities: { showTravelHistory = true }, // Now opens Travel History
                    onOpenCalendar: { selection = 1 },
                    onOpenLocations: { selection = 3 },
                    onOpenInfographics: { selection = 4 }
                )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
                .environmentObject(store)
                
                ModernEventsCalendarView()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }
                    .tag(1)

                DonutChartView(yearSelection: "Total")
                    .tabItem {
                        Label("Charts", systemImage: "chart.pie.fill")
                    }
                    .environmentObject(store)
                    .environmentObject(ChartDataContainer(store: store))
                    .tag(2)
                
                // Unified view combining map and list
                LocationsUnifiedView()
                    .tabItem {
                        Label("Locations", systemImage: "map.circle.fill")
                    }
                    .tag(3)
                
                // Infographics view
                InfographicsView()
                    .tabItem {
                        Label("Infographic", systemImage: "chart.bar.doc.horizontal")
                    }
                    .tag(4)
            }
            // Centralized title based on selected tab
            .navigationTitle(navigationTitleForSelection(selection))
            .onAppear {
                print("🚀 StartTabView appeared")
                print("📝 isFirstLaunch: \(store.isFirstLaunch)")
                print("📦 Locations count: \(store.locations.count)")
                print("✅ hasCompletedFirstLaunch: \(UserDefaults.standard.bool(forKey: "hasCompletedFirstLaunch"))")
                
                let backupURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("backup.json")
                print("📄 backup.json exists: \(FileManager.default.fileExists(atPath: backupURL.path))")
                
                // First launch wizard
                if store.isFirstLaunch {
                    print("🎉 Showing First Launch Wizard!")
                    showFirstLaunchWizard = true
                }
            }
            // Observe pendingTrip (equatable Bool) and map to sheet-driving item
            .onChange(of: store.pendingTrip != nil) { _, hasPending in
                print("UI Root (StartTabView): hasPendingTrip? \(hasPending)")
                if hasPending, let p = store.pendingTrip {
                    pendingItem = PendingTripItem(trip: p.trip, fromEvent: p.fromEvent, toEvent: p.toEvent)
                } else {
                    pendingItem = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            showAbout = true
                        } label: {
                            Label("About LocTrac", systemImage: "info.circle")
                        }
                        
                        // Travel History option (moved here)
                        Button {
                            showTravelHistory = true
                        } label: {
                            Label("Travel History", systemImage: "airplane.departure")
                        }
                        
                        Divider()
                        
                        // Manage Locations option
                        Button {
                            showLocationsManagement = true
                        } label: {
                            Label("Manage Locations", systemImage: "map")
                        }
                        
                        Button {
                            showActivitiesManager = true
                        } label: {
                            Label("Manage Activites & Affirmations", systemImage: "slider.horizontal.3")
                        }
                        
                        Button {
                            showTripsManagement = true
                        } label: {
                            Label("Manage Trips", systemImage: "airplane")
                        }
                        
                        // DISABLED: Sync Event Coordinates
                        // TODO: Re-enable once use case is clarified
                        // Button {
                        //     showLocationSync = true
                        // } label: {
                        //     Label("Sync Event Coordinates", systemImage: "arrow.triangle.2.circlepath")
                        // }
                        
                        Divider()
                        
                        // Backup & Import option
                        Button {
                            showBackupExport = true
                        } label: {
                            Label("Backup & Import", systemImage: "square.and.arrow.up")
                        }
                        
                        // Update Event Countries - HIDDEN for now
                        // Button {
                        //     showCountryUpdater = true
                        // } label: {
                        //     Label("Update Event Countries", systemImage: "globe.americas")
                        // }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Options")
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutLocTracView()
            }
            .sheet(isPresented: $showFirstLaunchWizard) {
                FirstLaunchWizard()
                    .environmentObject(store)
            }
            .sheet(item: $lformType) { $0 } // Presents LocationFormView via LocationFormType
            .sheet(isPresented: $showActivitiesManager) {
                ManagementView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showLocationsManagement) {
                LocationsManagementView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTripsManagement) {
                TripsManagementView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showBackupExport) {
                print("🔷 [StartTabView] Presenting BackupExportView sheet")
                // Present Backup & Import view (renamed)
                return BackupExportView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showImportGolfshot) {
                ImportGolfshotView(isPresented: $showImportGolfshot)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTravelHistory) {
                TravelHistoryView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showLocationSync) {
                LocationSyncUtilityView()
                    .environmentObject(store)
            }
            // Trip confirmation sheet
            .sheet(item: $pendingItem, onDismiss: {
                store.pendingTrip = nil
            }) { item in
                TripConfirmationView(
                    trip: item.trip,
                    fromEvent: item.fromEvent,
                    toEvent: item.toEvent,
                    onConfirm: { selectedMode, notes in
                        var updatedTrip = item.trip
                        updatedTrip.mode = selectedMode
                        updatedTrip.notes = notes
                        updatedTrip.recalculateCO2()
                        store.addTrip(updatedTrip)
                        store.pendingTrip = nil
                        pendingItem = nil
                    },
                    onCancel: {
                        store.pendingTrip = nil
                        pendingItem = nil
                    }
                )
                .environmentObject(store)
            }
            // Country updater sheet - HIDDEN for now
            // .sheet(isPresented: $showCountryUpdater) {
            //     EventCountryUpdaterView()
            //         .environmentObject(store)
            // }
        }
    }
    
    private func navigationTitleForSelection(_ selection: Int) -> String {
        switch selection {
        case 0: return "Home"
        case 1: return "Stays"
        case 2: return "Stays Overview"
        case 3: return "Locations"
        case 4: return "Infographic"
        default: return ""
        }
    }
}

struct StartTabView_Previews: PreviewProvider {
    static var previews: some View {
        StartTabView()
            .environmentObject(DataStore())
    }
}
