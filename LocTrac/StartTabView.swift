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
    @State private var showOtherCities: Bool = false // NEW: For Other cities view
    @State private var showBackupExport: Bool = false // NEW: For backup/import
    @State private var showFirstLaunchWizard: Bool = false // NEW: For first launch wizard
    @State private var showTripsManagement: Bool = false // NEW: For trips management
    @State private var showDefaultLocation: Bool = false // NEW: For default location settings
    @State private var showImportGolfshot: Bool = false // NEW: For Golfshot CSV import
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                // Home tab
                HomeView(
                    onAddEvent: { selection = 1 },
                    onAddLocation: { lformType = .new },
                    onShowOtherCities: { showOtherCities = true },
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
                // First launch wizard
                if store.isFirstLaunch {
                    showFirstLaunchWizard = true
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
                        
                        Divider()
                        
                        // Add Location option
                        Button {
                            lformType = .new
                        } label: {
                            Label("Add Location", systemImage: "plus.circle")
                        }
                        
                        Button {
                            showActivitiesManager = true
                        } label: {
                            Label("Manage Activities", systemImage: "list.bullet")
                        }
                        
                        Button {
                            showTripsManagement = true
                        } label: {
                            Label("Manage Trips", systemImage: "airplane")
                        }
                        
                        Button {
                            showDefaultLocation = true
                        } label: {
                            Label("Default Location", systemImage: "mappin.circle")
                        }
                        
                        Divider()
                        
                        // Import Golfshot CSV
                        Button {
                            showImportGolfshot = true
                        } label: {
                            Label("Import Golfshot CSV…", systemImage: "tray.and.arrow.down")
                        }
                        
                        // Backup & Import option (renamed)
                        Button {
                            showBackupExport = true
                        } label: {
                            Label("Backup & Import", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        // View Other Cities option
                        if store.locations.contains(where: { $0.name == "Other" }) {
                            Button {
                                showOtherCities = true
                            } label: {
                                Label("View Other Cities", systemImage: "mappin.and.ellipse")
                            }
                        }
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
                ActivitiesMaintenanceView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTripsManagement) {
                TripsManagementView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showDefaultLocation) {
                DefaultLocationSettingsView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showBackupExport) {
                // Present Backup & Import view (renamed)
                BackupExportView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showImportGolfshot) {
                ImportGolfshotView(isPresented: $showImportGolfshot)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showOtherCities) {
                if store.locations.contains(where: { $0.name == "Other" }),
                   let otherLocation = store.locations.first(where: { $0.name == "Other" }) {
                    NavigationStack {
                        OtherCitiesListView(location: otherLocation)
                            .environmentObject(store)
                            .navigationTitle("Other Cities & Dates")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showOtherCities = false
                                    }
                                }
                            }
                    }
                }
            }
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
