//
// Author Tim Arey
//

import SwiftUI

struct StartTabView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var authState: AuthState
    @State private var selection: Int = 0 // Start on Home tab
    @State private var showAbout: Bool = false
    @State private var showProfile: Bool = false // v2.0: Profile & Settings
    @State private var lformType: LocationFormType? // For adding/updating locations
    @State private var eventFormType: EventFormType? // For smart stay add/edit from Home
    @State private var showActivitiesManager: Bool = false
    @State private var showBackupExport: Bool = false // For backup/import
    @State private var showFirstLaunchWizard: Bool = false // For first launch wizard
    @State private var showTripsManagement: Bool = false // For trips management
    @State private var showImportGolfshot: Bool = false // For Golfshot CSV import
    @State private var showLocationsManagement: Bool = false // For managing locations
    @State private var showEventTypesManagement: Bool = false // v2.0: For managing event types
    @State private var showTravelHistory: Bool = false // For comprehensive travel history
    @State private var showCountryUpdater: Bool = false // For updating event countries
    @State private var showLocationSync: Bool = false // For syncing event coordinates
    @State private var showWhatsNew: Bool = false     // For "What's New" on version upgrade
    @State private var showLocationEnhancement: Bool = false // For location data enhancement
    @State private var showDebugSettings: Bool = false // For debug system settings (DEBUG only)
    @State private var showOrphanedEventsAnalyzer: Bool = false // For orphaned events management
    @State private var showBulkPersonAssign: Bool = false // Bulk assign a contact to events in date range
    @State private var showNotificationSettings: Bool = false // For notification settings
    
    // Debug configuration
    @StateObject private var debugConfig = DebugConfig.shared
    
    // Drives TripConfirmationView sheet
    @State private var pendingItem: PendingTripItem?
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                // Home tab
                HomeView(
                    onSmartStayAction: { action in handleSmartStayAction(action) },
                    onShowOtherCities: { showTravelHistory = true },
                    onOpenCalendar: { selection = 1 },
                    onOpenLocationsManagement: { showLocationsManagement = true },
                    onOpenInfographics: { selection = 4 },
                    onSwitchToMapTab: { selection = 2 }
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
                        Label("Travel Map", systemImage: "mappin.and.ellipse")
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
                #if DEBUG
                DebugConfig.shared.log(.startup, "StartTabView appeared")
                DebugConfig.shared.log(.startup, "isFirstLaunch: \(store.isFirstLaunch)")
                DebugConfig.shared.log(.startup, "Locations count: \(store.locations.count)")
                #endif
                print("✅ hasCompletedFirstLaunch: \(UserDefaults.standard.bool(forKey: "hasCompletedFirstLaunch"))")
                
                let backupURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("backup.json")
                print("📄 backup.json exists: \(FileManager.default.fileExists(atPath: backupURL.path))")
                
                // Skip modal sheets during UI testing
                let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")

                // First launch wizard
                if store.isFirstLaunch && !isUITesting {
                    print("🎉 Showing First Launch Wizard!")
                    showFirstLaunchWizard = true
                }

                // "What's New" sheet — shown once per version upgrade (not on very first launch)
                if !store.isFirstLaunch && AppVersionManager.shouldShowWhatsNew && !isUITesting {
                    print("🆕 Showing What's New for version \(AppVersionManager.currentVersion)")
                    showWhatsNew = true
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
                        // v2.0: Profile & Account
                        Button {
                            showProfile = true
                        } label: {
                            Label("Profile & Account", systemImage: "person.circle")
                        }

                        Divider()

                        // MARK: - About & Notifications

                        Button {
                            showAbout = true
                        } label: {
                            Label("About LocTrac", systemImage: "info.circle")
                        }

                        Button {
                            showNotificationSettings = true
                        } label: {
                            Label("Notifications", systemImage: "bell.badge")
                        }

                        Divider()

                        // MARK: - Manage Data (submenu)

                        Menu {
                            Button {
                                showLocationsManagement = true
                            } label: {
                                Label("Manage Locations", systemImage: "map")
                            }

                            Button {
                                showEventTypesManagement = true
                            } label: {
                                Label("Manage Event Types", systemImage: "tag")
                            }

                            Button {
                                showActivitiesManager = true
                            } label: {
                                Label("Activities & Affirmations", systemImage: "slider.horizontal.3")
                            }

                            Button {
                                showTripsManagement = true
                            } label: {
                                Label("Manage Trips", systemImage: "airplane")
                            }
                        } label: {
                            Label("Manage Data", systemImage: "tray.full.fill")
                        }

                        Divider()

                        Button {
                            showTravelHistory = true
                        } label: {
                            Label("Travel History", systemImage: "airplane.departure")
                        }

                        Divider()

                        // MARK: - Administration (submenu)

                        Menu {
                            // Data Management sub-items
                            Button {
                                showBackupExport = true
                            } label: {
                                Label("Backup & Import", systemImage: "square.and.arrow.up")
                            }

                            Button {
                                showLocationEnhancement = true
                            } label: {
                                Label("Enhance Location Data", systemImage: "wand.and.stars")
                            }

                            Button {
                                showBulkPersonAssign = true
                            } label: {
                                Label("Bulk Assign Person", systemImage: "person.badge.plus")
                            }

                            #if DEBUG
                            Button {
                                showOrphanedEventsAnalyzer = true
                            } label: {
                                Label("Fix Orphaned Events (Debug)", systemImage: "wrench.and.screwdriver")
                            }

                            Divider()

                            // Debug Settings — gated by compile-time flag
                            if DebugConfig.showDebugMenu {
                                Button {
                                    showDebugSettings = true
                                } label: {
                                    Label("Debug Settings", systemImage: "hammer.fill")
                                }
                            }
                            #endif
                        } label: {
                            Label("Administration", systemImage: "gearshape.2.fill")
                        }

                        // DISABLED: Sync Event Coordinates
                        // TODO: Re-enable once use case is clarified
                        // Button {
                        //     showLocationSync = true
                        // } label: {
                        //     Label("Sync Event Coordinates", systemImage: "arrow.triangle.2.circlepath")
                        // }

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
                
                // Share button for Infographics tab only
                if selection == 4 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                print("🔘 PDF export button tapped")
                                NotificationCenter.default.post(name: NSNotification.Name("GeneratePDF"), object: nil)
                            } label: {
                                Label("Export as PDF", systemImage: "doc.fill")
                            }
                            
                            Button {
                                print("🔘 Screenshot share button tapped")
                                NotificationCenter.default.post(name: NSNotification.Name("ShareScreenshot"), object: nil)
                            } label: {
                                Label("Share Screenshot", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .imageScale(.large)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutLocTracView()
            }
            // v2.0: Profile & Account sheet
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView()
                        .environmentObject(authState)
                        .environmentObject(store)
                        .navigationTitle("Profile")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showProfile = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showFirstLaunchWizard) {
                FirstLaunchWizard()
                    .environmentObject(store)
            }
            .sheet(item: $lformType) { $0 } // Presents LocationFormView via LocationFormType
            .sheet(item: $eventFormType) { formType in
                formType.environmentObject(store)
            }
            .sheet(isPresented: $showActivitiesManager) {
                ManagementView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showLocationsManagement) {
                LocationsManagementView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showEventTypesManagement) {
                EventTypesManagementView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTripsManagement) {
                TripsManagementView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showBackupExport) {
                BackupExportView()
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
            .sheet(isPresented: $showLocationEnhancement) {
                LocationDataEnhancementView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showOrphanedEventsAnalyzer) {
                OrphanedEventsAnalyzerView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showBulkPersonAssign) {
                BulkPersonAssignView()
                    .environmentObject(store)
            }
            // "What's New" version upgrade sheet
            .sheet(isPresented: $showWhatsNew, onDismiss: {
                AppVersionManager.markCurrentVersionSeen()
            }) {
                WhatsNewView()
            }
            // Debug Settings sheet (DEBUG only)
            #if DEBUG
            .sheet(isPresented: $showDebugSettings) {
                DebugSettingsView()
                    .environmentObject(debugConfig)
            }
            #endif
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
        .debugViewName("StartTabView")
    }
    
    private func handleSmartStayAction(_ action: SmartStayAction) {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        switch action {
        case .addToday:
            let today = Date().startOfDay
            let components = utcCalendar.dateComponents([.year, .month, .day], from: today)
            eventFormType = .new(components)

        case .fillGap(let from, let to, _):
            let vm = EventFormViewModel(dateSelected: from.startOfDay, toDateSelected: to.startOfDay)
            eventFormType = .newWithViewModel(vm)

        case .editToday(let event):
            eventFormType = .update(event)
        }
    }

    private func navigationTitleForSelection(_ selection: Int) -> String {
        switch selection {
        case 0: return "Home"
        case 1: return "Stays"
        case 2: return "Stays Overview"
        case 3: return "Travel Map"
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
