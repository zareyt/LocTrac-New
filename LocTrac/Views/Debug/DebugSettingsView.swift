//
//  DebugSettingsView.swift
//  LocTrac
//
//  Created on 2026-04-13
//  UI for controlling debug features
//

import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var debugConfig: DebugConfig
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Master Control
                Section {
                    Toggle("Enable Debug Mode", isOn: $debugConfig.isEnabled)
                        .tint(.orange)
                } header: {
                    Text("Master Control")
                } footer: {
                    Text("When disabled, all debug features are turned off. This is the master switch.")
                }
                
                // Quick Presets
                if debugConfig.isEnabled {
                    Section {
                        Button("Enable All") {
                            debugConfig.enableAll()
                        }
                        
                        Button("Disable All") {
                            debugConfig.disableAll()
                        }
                        
                        Button("UI Debug Only") {
                            debugConfig.presetUI()
                        }
                        
                        Button("Data Debug Only") {
                            debugConfig.presetData()
                        }
                    } header: {
                        Text("Quick Presets")
                    }
                }
                
                // UI Debug Features
                if debugConfig.isEnabled {
                    Section {
                        Toggle("Show View Names", isOn: $debugConfig.showViewNames)
                        Toggle("Show Lifecycle Events", isOn: $debugConfig.showLifecycle)
                        Toggle("Show Performance Metrics", isOn: $debugConfig.showPerformance)
                    } header: {
                        Text("UI Debug Features")
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• View Names: Shows view name in italics at bottom")
                            Text("• Lifecycle: Logs onAppear/onDisappear to console")
                            Text("• Performance: Counts how many times body{} runs")
                        }
                        .font(.caption)
                    }
                }
                
                // Logging Categories
                if debugConfig.isEnabled {
                    Section {
                        HStack {
                            Text("💾 DataStore Operations")
                            Spacer()
                            Toggle("", isOn: $debugConfig.logDataStore)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("📁 Persistence (Save/Load)")
                            Spacer()
                            Toggle("", isOn: $debugConfig.logPersistence)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("🧭 Navigation & Sheets")
                            Spacer()
                            Toggle("", isOn: $debugConfig.logNavigation)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("🌐 Network & Geocoding")
                            Spacer()
                            Toggle("", isOn: $debugConfig.logNetwork)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("⚡ Cache Operations")
                            Spacer()
                            Toggle("", isOn: $debugConfig.logCache)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("✈️ Trip Calculations")
                            Spacer()
                            Toggle("", isOn: $debugConfig.logTrips)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("📈 Charts & Visualization")
                            Spacer()
                            Toggle("", isOn: $debugConfig.logCharts)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("📝 Markdown Parsing")
                            Spacer()
                            Toggle("", isOn: $debugConfig.logParser)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("🚀 App Startup")
                            Spacer()
                            Toggle("", isOn: $debugConfig.logStartup)
                                .labelsHidden()
                        }
                    } header: {
                        Text("Console Logging")
                    } footer: {
                        Text("Enable logging for specific subsystems. Logs appear in Xcode console with emoji prefixes and timestamps.")
                            .font(.caption)
                    }
                }
                
                // Info
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Debug features are designed to help during development:")
                            .font(.subheadline)
                        
                        Text("• **View Names**: Quick visual identification of which view is displaying")
                        Text("• **Lifecycle Logging**: Track view appearance/disappearance")
                        Text("• **Performance**: Identify excessive body recomputations")
                        Text("• **Category Logging**: Granular control over console output")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text("About Debug Mode")
                }
            }
            .navigationTitle("Debug Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .debugViewName("DebugSettingsView")
    }
}

// MARK: - Preview

#Preview {
    DebugSettingsView()
        .environmentObject(DebugConfig.shared)
}
