//
//  Car.swift
//  LocTrac
//
//  Vehicle model for environmental impact calculations.
//  Each car has a fuel type, efficiency rating, and date range
//  for matching to driving trips.
//

import Foundation

struct Car: Identifiable, Codable, Hashable {
    var id: String
    var name: String                // e.g. "2024 Tesla Model 3"
    var year: Int?
    var make: String?
    var model: String?
    var fuelType: FuelType
    var mpg: Double?                // For gas/diesel/hybrid
    var kWhPer100Miles: Double?     // For electric
    var co2PerMileOverride: Double? // User override (lbs CO2/mile)
    var startDate: Date
    var endDate: Date?              // nil = current/active
    var isDefault: Bool
    var notes: String

    init(
        id: String = UUID().uuidString,
        name: String,
        year: Int? = nil,
        make: String? = nil,
        model: String? = nil,
        fuelType: FuelType = .gas,
        mpg: Double? = nil,
        kWhPer100Miles: Double? = nil,
        co2PerMileOverride: Double? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        isDefault: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.year = year
        self.make = make
        self.model = model
        self.fuelType = fuelType
        self.mpg = mpg
        self.kWhPer100Miles = kWhPer100Miles
        self.co2PerMileOverride = co2PerMileOverride
        self.startDate = startDate
        self.endDate = endDate
        self.isDefault = isDefault
        self.notes = notes
    }

    // MARK: - Fuel Type

    enum FuelType: String, Codable, CaseIterable {
        case gas = "Gas"
        case diesel = "Diesel"
        case hybrid = "Hybrid"
        case electric = "Electric"

        var displayName: String { rawValue }

        var sfSymbol: String {
            switch self {
            case .gas:      return "fuelpump.fill"
            case .diesel:   return "fuelpump.fill"
            case .hybrid:   return "leaf.arrow.triangle.circlepath"
            case .electric: return "bolt.car.fill"
            }
        }

        /// Default MPG assumption when user hasn't entered a value
        var defaultMPG: Double? {
            switch self {
            case .gas:      return 25.0
            case .diesel:   return 30.0
            case .hybrid:   return 35.0
            case .electric: return nil  // Electric uses kWh, not MPG
            }
        }

        /// Default kWh/100 miles for electric vehicles
        var defaultKWhPer100Miles: Double? {
            switch self {
            case .electric: return 30.0   // Average EV ~30 kWh/100mi
            default:        return nil
            }
        }
    }

    // MARK: - CO2 Calculation

    /// EPA constants for CO2 per gallon of fuel (in lbs)
    static let gasCO2PerGallon: Double = 19.6       // 8,887g / 453.6g/lb
    static let dieselCO2PerGallon: Double = 22.4     // 10,180g / 453.6g/lb
    static let gridCO2PerKWh: Double = 0.855         // EPA US average lbs CO2/kWh

    /// Computed CO2 per mile in lbs, using override if set, otherwise derived from fuel type + efficiency
    var co2PerMile: Double {
        if let override = co2PerMileOverride {
            return override
        }
        switch fuelType {
        case .gas:
            let effectiveMPG = mpg ?? FuelType.gas.defaultMPG ?? 25.0
            return Self.gasCO2PerGallon / effectiveMPG
        case .diesel:
            let effectiveMPG = mpg ?? FuelType.diesel.defaultMPG ?? 30.0
            return Self.dieselCO2PerGallon / effectiveMPG
        case .hybrid:
            let effectiveMPG = mpg ?? FuelType.hybrid.defaultMPG ?? 35.0
            return Self.gasCO2PerGallon / effectiveMPG
        case .electric:
            let effectiveKWh = kWhPer100Miles ?? FuelType.electric.defaultKWhPer100Miles ?? 30.0
            return (effectiveKWh / 100.0) * Self.gridCO2PerKWh
        }
    }

    /// Formatted CO2 per mile string
    var formattedCO2PerMile: String {
        String(format: "%.2f lbs/mi", co2PerMile)
    }

    // MARK: - Date Range Helpers

    /// Whether this car's date range covers the given date
    func coversDate(_ date: Date) -> Bool {
        let start = startDate.startOfDay
        let checkDate = date.startOfDay
        if checkDate < start { return false }
        if let end = endDate {
            return checkDate <= end.startOfDay
        }
        return true // No end date = still active
    }

    /// Whether this car is currently active (no end date or end date >= today)
    var isCurrent: Bool {
        guard let end = endDate else { return true }
        return end.startOfDay >= Date().startOfDay
    }

    /// Display string for the date range
    var dateRangeDescription: String {
        let start = startDate.utcMediumDateString
        if let end = endDate {
            return "\(start) – \(end.utcMediumDateString)"
        }
        return "\(start) – Present"
    }
}
