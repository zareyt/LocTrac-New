//
//  DebugConfig.swift
//  LocTrac
//
//  Created on 2026-04-13
//  Centralized debug configuration with granular control per subsystem
//

import SwiftUI

/// Global debug configuration
/// Access via @EnvironmentObject or DebugConfig.shared
/// Note: @MainActor required for @Published properties in Swift 6, but we make
/// the singleton accessible via nonisolated(unsafe) for logging from any context.
@MainActor
class DebugConfig: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance - main actor isolated.
    /// For use in SwiftUI views via @EnvironmentObject or direct access from main actor code.
    static let shared = DebugConfig()
    
    // MARK: - Master Control
    
    /// Master debug switch - controls all debug features
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "Debug.isEnabled")
            if !isEnabled {
                // When disabled, hide all debug UI
                showViewNames = false
            }
        }
    }
    
    // MARK: - UI Debug Features
    
    /// Show view names at bottom of screen in italics
    @Published var showViewNames: Bool {
        didSet {
            UserDefaults.standard.set(showViewNames, forKey: "Debug.showViewNames")
        }
    }
    
    /// Show view lifecycle events (onAppear, onDisappear)
    @Published var showLifecycle: Bool {
        didSet {
            UserDefaults.standard.set(showLifecycle, forKey: "Debug.showLifecycle")
        }
    }
    
    /// Show performance metrics (body recomputation counts)
    @Published var showPerformance: Bool {
        didSet {
            UserDefaults.standard.set(showPerformance, forKey: "Debug.showPerformance")
        }
    }
    
    // MARK: - Logging Categories
    
    /// DataStore operations (CRUD)
    @Published var logDataStore: Bool {
        didSet {
            UserDefaults.standard.set(logDataStore, forKey: "Debug.logDataStore")
        }
    }
    
    /// Persistence (save/load from backup.json)
    @Published var logPersistence: Bool {
        didSet {
            UserDefaults.standard.set(logPersistence, forKey: "Debug.logPersistence")
        }
    }
    
    /// Navigation & sheets
    @Published var logNavigation: Bool {
        didSet {
            UserDefaults.standard.set(logNavigation, forKey: "Debug.logNavigation")
        }
    }
    
    /// Network & geocoding
    @Published var logNetwork: Bool {
        didSet {
            UserDefaults.standard.set(logNetwork, forKey: "Debug.logNetwork")
        }
    }
    
    /// Cache operations (infographics, etc.)
    @Published var logCache: Bool {
        didSet {
            UserDefaults.standard.set(logCache, forKey: "Debug.logCache")
        }
    }
    
    /// Trip calculations and suggestions
    @Published var logTrips: Bool {
        didSet {
            UserDefaults.standard.set(logTrips, forKey: "Debug.logTrips")
        }
    }
    
    /// Charts and visualization rendering
    @Published var logCharts: Bool {
        didSet {
            UserDefaults.standard.set(logCharts, forKey: "Debug.logCharts")
        }
    }
    
    /// Markdown and release notes parsing
    @Published var logParser: Bool {
        didSet {
            UserDefaults.standard.set(logParser, forKey: "Debug.logParser")
        }
    }
    
    /// App initialization and startup
    @Published var logStartup: Bool {
        didSet {
            UserDefaults.standard.set(logStartup, forKey: "Debug.logStartup")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load from UserDefaults
        self.isEnabled = UserDefaults.standard.bool(forKey: "Debug.isEnabled")
        self.showViewNames = UserDefaults.standard.bool(forKey: "Debug.showViewNames")
        self.showLifecycle = UserDefaults.standard.bool(forKey: "Debug.showLifecycle")
        self.showPerformance = UserDefaults.standard.bool(forKey: "Debug.showPerformance")
        self.logDataStore = UserDefaults.standard.bool(forKey: "Debug.logDataStore")
        self.logPersistence = UserDefaults.standard.bool(forKey: "Debug.logPersistence")
        self.logNavigation = UserDefaults.standard.bool(forKey: "Debug.logNavigation")
        self.logNetwork = UserDefaults.standard.bool(forKey: "Debug.logNetwork")
        self.logCache = UserDefaults.standard.bool(forKey: "Debug.logCache")
        self.logTrips = UserDefaults.standard.bool(forKey: "Debug.logTrips")
        self.logCharts = UserDefaults.standard.bool(forKey: "Debug.logCharts")
        self.logParser = UserDefaults.standard.bool(forKey: "Debug.logParser")
        self.logStartup = UserDefaults.standard.bool(forKey: "Debug.logStartup")
    }
    
    // MARK: - Quick Presets
    
    /// Enable all debug features
    func enableAll() {
        isEnabled = true
        showViewNames = true
        showLifecycle = true
        showPerformance = true
        logDataStore = true
        logPersistence = true
        logNavigation = true
        logNetwork = true
        logCache = true
        logTrips = true
        logCharts = true
        logParser = true
        logStartup = true
    }
    
    /// Disable all debug features
    func disableAll() {
        isEnabled = false
        showViewNames = false
        showLifecycle = false
        showPerformance = false
        logDataStore = false
        logPersistence = false
        logNavigation = false
        logNetwork = false
        logCache = false
        logTrips = false
        logCharts = false
        logParser = false
        logStartup = false
    }
    
    /// Preset: UI debugging only
    func presetUI() {
        isEnabled = true
        showViewNames = true
        showLifecycle = true
        showPerformance = true
        logDataStore = false
        logPersistence = false
        logNavigation = true
        logNetwork = false
        logCache = false
        logTrips = false
        logCharts = false
        logParser = false
        logStartup = false
    }
    
    /// Preset: Data debugging only
    func presetData() {
        isEnabled = true
        showViewNames = false
        showLifecycle = false
        showPerformance = false
        logDataStore = true
        logPersistence = true
        logNavigation = false
        logNetwork = true
        logCache = true
        logTrips = true
        logCharts = false
        logParser = false
        logStartup = false
    }
}

// MARK: - Logging Helper

extension DebugConfig {
    
    /// Log a message if the category is enabled.
    /// Must be called from main actor context (or use Task { await DebugConfig.shared.log(...) })
    /// - Parameters:
    ///   - category: The logging category (e.g., .dataStore, .network)
    ///   - message: The message to log
    ///   - file: Source file (auto-populated)
    ///   - function: Function name (auto-populated)
    ///   - line: Line number (auto-populated)
    func log(
        _ category: LogCategory,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        guard category.isEnabled(in: self) else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        print("\(category.emoji) [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    }
}

// MARK: - Log Categories

enum LogCategory {
    case dataStore
    case persistence
    case navigation
    case network
    case cache
    case trips
    case lifecycle
    case performance
    case charts
    case parser
    case startup
    
    var emoji: String {
        switch self {
        case .dataStore: return "💾"
        case .persistence: return "📁"
        case .navigation: return "🧭"
        case .network: return "🌐"
        case .cache: return "⚡"
        case .trips: return "✈️"
        case .lifecycle: return "🔄"
        case .performance: return "📊"
        case .charts: return "📈"
        case .parser: return "📝"
        case .startup: return "🚀"
        }
    }
    
    @MainActor
    func isEnabled(in config: DebugConfig) -> Bool {
        switch self {
        case .dataStore: return config.logDataStore
        case .persistence: return config.logPersistence
        case .navigation: return config.logNavigation
        case .network: return config.logNetwork
        case .cache: return config.logCache
        case .trips: return config.logTrips
        case .lifecycle: return config.showLifecycle
        case .performance: return config.showPerformance
        case .charts: return config.logCharts
        case .parser: return config.logParser
        case .startup: return config.logStartup
        }
    }
}

// MARK: - View Modifier

struct DebugViewName: ViewModifier {
    let viewName: String
    @EnvironmentObject var debugConfig: DebugConfig
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if debugConfig.isEnabled && debugConfig.showViewNames {
                    Text(viewName)
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 4)
                }
            }
            .onAppear {
                if debugConfig.isEnabled && debugConfig.showLifecycle {
                    debugConfig.log(.lifecycle, "\(viewName) appeared")
                }
            }
            .onDisappear {
                if debugConfig.isEnabled && debugConfig.showLifecycle {
                    debugConfig.log(.lifecycle, "\(viewName) disappeared")
                }
            }
    }
}

extension View {
    /// Add debug view name overlay (shows when debug mode enabled)
    func debugViewName(_ name: String) -> some View {
        modifier(DebugViewName(viewName: name))
    }
}
