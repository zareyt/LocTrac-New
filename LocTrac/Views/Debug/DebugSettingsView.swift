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
                masterControlSection
                if debugConfig.isEnabled {
                    presetsSection
                    uiFeaturesSection
                    loggingCategoriesSection
                    fileLoggingSection
                    activeCountSection
                    aboutSection
                }
            }
            .navigationTitle("Debug Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .debugViewName("DebugSettingsView")
    }

    // MARK: - Sections

    private var masterControlSection: some View {
        Section {
            Toggle("Enable Debug Mode", isOn: $debugConfig.isEnabled)
                .tint(.orange)
        } header: {
            Text("Master Control")
        } footer: {
            Text("When disabled, all debug features and logging are turned off.")
        }
    }

    private var presetsSection: some View {
        Section {
            HStack(spacing: 12) {
                PresetButton(title: "All On", icon: "checkmark.circle.fill", color: .green) {
                    debugConfig.enableAll()
                }
                PresetButton(title: "All Off", icon: "xmark.circle.fill", color: .red) {
                    debugConfig.disableAll()
                }
                PresetButton(title: "UI Only", icon: "rectangle.on.rectangle", color: .blue) {
                    debugConfig.presetUI()
                }
                PresetButton(title: "Data Only", icon: "externaldrive.fill", color: .purple) {
                    debugConfig.presetData()
                }
            }
            .buttonStyle(.borderless)
        } header: {
            Text("Quick Presets")
        }
    }

    private var uiFeaturesSection: some View {
        Section {
            DebugToggleRow(
                emoji: "🏷️",
                title: "Show View Names",
                subtitle: "Overlay view name at bottom of each screen",
                isOn: $debugConfig.showViewNames
            )
            DebugToggleRow(
                emoji: "🔄",
                title: "Lifecycle Events",
                subtitle: "Log onAppear/onDisappear to console",
                isOn: $debugConfig.showLifecycle
            )
            DebugToggleRow(
                emoji: "📊",
                title: "Performance Metrics",
                subtitle: "Count body recomputations",
                isOn: $debugConfig.showPerformance
            )
        } header: {
            Text("UI Debug Features")
        }
    }

    private var loggingCategoriesSection: some View {
        Section {
            Group {
                DebugToggleRow(emoji: "💾", title: "DataStore", subtitle: "CRUD operations", isOn: $debugConfig.logDataStore)
                DebugToggleRow(emoji: "📁", title: "Persistence", subtitle: "Save/load backup.json", isOn: $debugConfig.logPersistence)
                DebugToggleRow(emoji: "🧭", title: "Navigation", subtitle: "Sheets and navigation events", isOn: $debugConfig.logNavigation)
                DebugToggleRow(emoji: "🌐", title: "Network", subtitle: "Geocoding and API calls", isOn: $debugConfig.logNetwork)
                DebugToggleRow(emoji: "⚡", title: "Cache", subtitle: "Infographics cache operations", isOn: $debugConfig.logCache)
                DebugToggleRow(emoji: "✈️", title: "Trips", subtitle: "Trip calculations and suggestions", isOn: $debugConfig.logTrips)
            }
            Group {
                DebugToggleRow(emoji: "📈", title: "Charts", subtitle: "Chart and visualization rendering", isOn: $debugConfig.logCharts)
                DebugToggleRow(emoji: "📝", title: "Parser", subtitle: "Markdown and release notes parsing", isOn: $debugConfig.logParser)
                DebugToggleRow(emoji: "🚀", title: "Startup", subtitle: "App initialization and launch", isOn: $debugConfig.logStartup)
                DebugToggleRow(emoji: "📷", title: "Photos", subtitle: "Photo add, delete, import/export", isOn: $debugConfig.logPhotos)
                DebugToggleRow(emoji: "📅", title: "Calendar", subtitle: "Decorations and date rendering", isOn: $debugConfig.logCalendar)
                DebugToggleRow(emoji: "🔐", title: "Auth", subtitle: "Authentication and profile", isOn: $debugConfig.logAuth)
            }
        } header: {
            Text("Console Logging Categories")
        } footer: {
            Text("Each category controls a group of log statements. Log format:\nemoji [category] [time] [file:line] function - message")
                .font(.caption)
        }
    }

    private var fileLoggingSection: some View {
        Section {
            DebugToggleRow(
                emoji: "📄",
                title: "Log to File",
                subtitle: "Also write log output to DebugLogs/debug_log.txt",
                isOn: $debugConfig.logToFile
            )

            if debugConfig.logToFile {
                HStack {
                    Text("Log file size")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: debugConfig.logFileSize, countStyle: .file))
                        .foregroundColor(.secondary)
                }

                Button(role: .destructive) {
                    debugConfig.clearLogFile()
                } label: {
                    Label("Clear Log File", systemImage: "trash")
                }
            }
        } header: {
            Text("File Logging")
        } footer: {
            if debugConfig.logToFile {
                Text("Log file: \(DebugConfig.logFilePath.path)")
                    .font(.caption2)
                    .textSelection(.enabled)
            }
        }
    }

    private var activeCountSection: some View {
        Section {
            let count = activeLogCategoryCount
            let total = 12
            HStack {
                Text("Active categories")
                Spacer()
                Text("\(count) / \(total)")
                    .foregroundColor(count == 0 ? .secondary : .orange)
                    .fontWeight(.medium)
            }

            let uiCount = [debugConfig.showViewNames, debugConfig.showLifecycle, debugConfig.showPerformance].filter { $0 }.count
            HStack {
                Text("Active UI features")
                Spacer()
                Text("\(uiCount) / 3")
                    .foregroundColor(uiCount == 0 ? .secondary : .blue)
                    .fontWeight(.medium)
            }
        } header: {
            Text("Status")
        }
    }

    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Debug logging is gated behind the master switch and individual category toggles. Output goes to the Xcode console, and optionally to a log file that Claude can read directly.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("View Names overlay shows the SwiftUI view name at the bottom of each screen for quick identification.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private var activeLogCategoryCount: Int {
        [
            debugConfig.logDataStore,
            debugConfig.logPersistence,
            debugConfig.logNavigation,
            debugConfig.logNetwork,
            debugConfig.logCache,
            debugConfig.logTrips,
            debugConfig.logCharts,
            debugConfig.logParser,
            debugConfig.logStartup,
            debugConfig.logPhotos,
            debugConfig.logCalendar,
            debugConfig.logAuth,
        ].filter { $0 }.count
    }
}

// MARK: - Subviews

private struct DebugToggleRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.body)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(.orange)
    }
}

private struct PresetButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview {
    DebugSettingsView()
        .environmentObject(DebugConfig.shared)
}
