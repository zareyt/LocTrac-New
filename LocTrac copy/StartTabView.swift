//
// Author Tim Arey
//

import SwiftUI

struct StartTabView: View {
    @EnvironmentObject var store: DataStore
    @State private var selection: Int = 2 // Default to Locations tab (now unified)
    @State private var showAbout: Bool = false
    @State private var lformType: LocationFormType? // For adding/updating locations
    @State private var showActivitiesManager: Bool = false
    @State private var showOtherCities: Bool = false // NEW: For Other cities view
    @State private var showBackupExport: Bool = false // NEW: For backup/export
    @State private var showFirstLaunchWizard: Bool = false // NEW: For first launch wizard
    @State private var showTripsManagement: Bool = false // NEW: For trips management
    @State private var showDefaultLocation: Bool = false // NEW: For default location settings
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ModernEventsCalendarView()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }
                    .tag(0)

                DonutChartView(yearSelection: "Total")
                    .tabItem {
                        Label("Charts", systemImage: "chart.pie.fill")
                    }
                    .environmentObject(store)
                    .environmentObject(ChartDataContainer(store: store))
                    .tag(1)
                
                // NEW: Unified view combining map and list
                LocationsUnifiedView()
                    .tabItem {
                        Label("Locations", systemImage: "map.circle.fill")
                    }
                    .tag(2)
                
                // NEW: Infographics view
                InfographicsView()
                    .tabItem {
                        Label("Infographic", systemImage: "chart.bar.doc.horizontal")
                    }
                    .tag(3)
            }
            // Centralized title based on selected tab
            .navigationTitle(navigationTitleForSelection(selection))
            .onAppear {
                // Check if this is first launch and show wizard
                print("🚀 StartTabView appeared")
                print("📝 isFirstLaunch: \(store.isFirstLaunch)")
                print("📦 Locations count: \(store.locations.count)")
                print("📦 Events count: \(store.events.count)")
                print("📦 Activities count: \(store.activities.count)")
                
                let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedFirstLaunch")
                let backupPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                    .first!.appendingPathComponent("backup.json").path
                let backupExists = FileManager.default.fileExists(atPath: backupPath)
                
                print("✅ hasCompletedFirstLaunch: \(hasCompleted)")
                print("📄 backup.json exists: \(backupExists)")
                print("📍 backup.json path: \(backupPath)")
                
                if store.isFirstLaunch {
                    print("🎉 Showing First Launch Wizard!")
                    showFirstLaunchWizard = true
                } else {
                    print("👍 Not first launch, proceeding normally")
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
                        
                        // NEW: Add Location option
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
                        
                        // NEW: Backup & Export option
                        Button {
                            showBackupExport = true
                        } label: {
                            Label("Backup & Export", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        // NEW: View Other Cities option
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
                // NEW: First launch wizard
                FirstLaunchWizard()
                    .environmentObject(store)
            }
            .sheet(item: $lformType) { $0 } // Presents LocationFormView via LocationFormType
            .sheet(isPresented: $showActivitiesManager) {
                ActivitiesMaintenanceView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTripsManagement) {
                // NEW: Present Trips Management view
                TripsManagementView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showDefaultLocation) {
                // NEW: Present Default Location Settings
                DefaultLocationSettingsView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showBackupExport) {
                // NEW: Present Backup & Export view
                BackupExportView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showOtherCities) {
                // NEW: Present Other Cities view
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
        case 0: return "Stays"
        case 1: return "Stays Overview"
        case 2: return "Locations"
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

