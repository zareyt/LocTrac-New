//
//  EnvironmentalFactorsView.swift
//  LocTrac
//
//  Manage vehicles and environmental calculation preferences.
//  Accessible from Settings > Manage Data > Environmental Factors.
//

import SwiftUI

struct EnvironmentalFactorsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) private var dismiss

    @State private var showCarForm = false
    @State private var editingCar: Car?
    @State private var excludePublicTransit: Bool = false
    @State private var showDeleteConfirmation = false
    @State private var carToDelete: Car?
    @State private var showRecalculateAlert = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Vehicles Section
                Section {
                    if store.cars.isEmpty {
                        Text("No vehicles added yet. Add a vehicle to track your driving environmental impact.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(store.cars.sorted(by: { ($0.isDefault ? 0 : 1, $0.startDate) < ($1.isDefault ? 0 : 1, $1.startDate) })) { car in
                            carRow(car)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingCar = car
                                }
                        }
                        .onDelete(perform: deleteCars)
                    }
                } header: {
                    HStack {
                        Text("My Vehicles")
                        Spacer()
                        Button {
                            showCarForm = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                } footer: {
                    Text("Vehicles are matched to driving trips by date range. The default vehicle (star) is used when multiple vehicles overlap.")
                }

                // MARK: - Environmental Settings
                Section {
                    Toggle("Exclude Public Transit", isOn: $excludePublicTransit)
                        .onChange(of: excludePublicTransit) { _, newValue in
                            savePublicTransitPreference(newValue)
                        }
                } header: {
                    Text("Calculation Settings")
                } footer: {
                    Text("When enabled, train and bus trips are excluded from CO\\u{2082} calculations in the Environmental Impact section of Infographics.")
                }

                // MARK: - Recalculate
                if !store.cars.isEmpty {
                    Section {
                        Button {
                            showRecalculateAlert = true
                        } label: {
                            Label("Recalculate All Driving Trip CO\\u{2082}", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } footer: {
                        Text("Updates CO\\u{2082} emissions for all driving trips using the matched vehicle's efficiency rating.")
                    }
                }

                // MARK: - Per-Car Impact Summary
                if !store.cars.isEmpty {
                    Section("Vehicle Impact Summary") {
                        ForEach(store.cars.sorted(by: { $0.startDate < $1.startDate })) { car in
                            carImpactRow(car)
                        }
                    }
                }
            }
            .navigationTitle("Environmental Factors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showCarForm) {
                CarFormView(car: nil) { newCar in
                    store.addCar(newCar)
                }
            }
            .sheet(item: $editingCar) { car in
                CarFormView(car: car) { updatedCar in
                    store.updateCar(updatedCar)
                }
            }
            .alert("Delete Vehicle?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let car = carToDelete {
                        store.deleteCar(car)
                        carToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { carToDelete = nil }
            } message: {
                if let car = carToDelete {
                    Text("Delete \"\(car.name)\"? This won't affect existing trip data.")
                }
            }
            .alert("Recalculate CO\\u{2082}?", isPresented: $showRecalculateAlert) {
                Button("Recalculate", role: .destructive) {
                    store.recalculateDrivingTripsCO2()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will update CO\\u{2082} emissions for all driving trips based on the matched vehicle for each trip's date.")
            }
            .onAppear {
                loadPublicTransitPreference()
            }
        }
    }

    // MARK: - Car Row

    @ViewBuilder
    private func carRow(_ car: Car) -> some View {
        HStack(spacing: 12) {
            Image(systemName: car.fuelType.sfSymbol)
                .font(.title3)
                .foregroundColor(fuelTypeColor(car.fuelType))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(car.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if car.isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
                Text(car.dateRangeDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(car.formattedCO2PerMile)
                    .font(.caption)
                    .fontWeight(.medium)
                if let mpg = car.mpg, car.fuelType != .electric {
                    Text("\(Int(mpg)) MPG")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if let kwh = car.kWhPer100Miles, car.fuelType == .electric {
                    Text("\(Int(kwh)) kWh/100mi")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                carToDelete = car
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Impact Summary Row

    @ViewBuilder
    private func carImpactRow(_ car: Car) -> some View {
        let drivingTrips = store.trips.filter { $0.mode == .driving && car.coversDate($0.departureDate) }
        let totalMiles = drivingTrips.reduce(0.0) { $0 + $1.distance }
        let totalCO2 = totalMiles * car.co2PerMile

        HStack(spacing: 12) {
            Image(systemName: car.fuelType.sfSymbol)
                .foregroundColor(fuelTypeColor(car.fuelType))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(car.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(drivingTrips.count) trips")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(formattedNumber(totalMiles)) mi")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("\(formattedNumber(totalCO2)) lbs CO\\u{2082}")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Helpers

    private func deleteCars(at offsets: IndexSet) {
        let sorted = store.cars.sorted(by: { ($0.isDefault ? 0 : 1, $0.startDate) < ($1.isDefault ? 0 : 1, $1.startDate) })
        for index in offsets {
            store.deleteCar(sorted[index])
        }
    }

    private func fuelTypeColor(_ type: Car.FuelType) -> Color {
        switch type {
        case .gas:      return .red
        case .diesel:   return .brown
        case .hybrid:   return .green
        case .electric: return .blue
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func loadPublicTransitPreference() {
        if let profile = authState.currentUser {
            excludePublicTransit = profile.excludePublicTransitFromEnvironment
        }
    }

    private func savePublicTransitPreference(_ value: Bool) {
        guard var profile = authState.currentUser else { return }
        profile.excludePublicTransitFromEnvironment = value
        try? profile.save()
        authState.currentUser = profile
    }
}

// MARK: - Car Form View

struct CarFormView: View {
    @Environment(\.dismiss) private var dismiss

    let existingCar: Car?
    let onSave: (Car) -> Void

    @State private var name: String = ""
    @State private var year: String = ""
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var fuelType: Car.FuelType = .gas
    @State private var mpgString: String = ""
    @State private var kWhString: String = ""
    @State private var co2Override: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var isDefault: Bool = false
    @State private var notes: String = ""

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    init(car: Car?, onSave: @escaping (Car) -> Void) {
        self.existingCar = car
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Info") {
                    TextField("Name (e.g. 2024 Tesla Model 3)", text: $name)
                    TextField("Year", text: $year)
                        .keyboardType(.numberPad)
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                }

                Section("Fuel & Efficiency") {
                    Picker("Fuel Type", selection: $fuelType) {
                        ForEach(Car.FuelType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.sfSymbol)
                                .tag(type)
                        }
                    }

                    if fuelType == .electric {
                        HStack {
                            Text("kWh per 100 miles")
                            Spacer()
                            TextField("30", text: $kWhString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    } else {
                        HStack {
                            Text("MPG")
                            Spacer()
                            TextField(fuelType.defaultMPG.map { "\(Int($0))" } ?? "25", text: $mpgString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }

                    HStack {
                        Text("CO\\u{2082} Override (lbs/mi)")
                        Spacer()
                        TextField("Auto", text: $co2Override)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    // Show computed CO2/mile
                    HStack {
                        Text("Effective CO\\u{2082}/mile")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.3f lbs", effectiveCO2PerMile))
                            .foregroundColor(.secondary)
                    }
                }

                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .environment(\.calendar, utcCalendar)
                        .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)

                    Toggle("Has End Date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                            .environment(\.calendar, utcCalendar)
                            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                    }
                }

                Section {
                    Toggle("Default Vehicle", isOn: $isDefault)
                } footer: {
                    Text("The default vehicle is used for new driving trips and when multiple vehicles overlap in date range.")
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existingCar == nil ? "Add Vehicle" : "Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCar()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let car = existingCar {
                    populateFromCar(car)
                }
            }
        }
    }

    // MARK: - Computed

    private var effectiveCO2PerMile: Double {
        if let overrideVal = Double(co2Override), overrideVal > 0 {
            return overrideVal
        }
        switch fuelType {
        case .gas:
            let mpg = Double(mpgString) ?? Car.FuelType.gas.defaultMPG ?? 25.0
            return Car.gasCO2PerGallon / mpg
        case .diesel:
            let mpg = Double(mpgString) ?? Car.FuelType.diesel.defaultMPG ?? 30.0
            return Car.dieselCO2PerGallon / mpg
        case .hybrid:
            let mpg = Double(mpgString) ?? Car.FuelType.hybrid.defaultMPG ?? 35.0
            return Car.gasCO2PerGallon / mpg
        case .electric:
            let kwh = Double(kWhString) ?? Car.FuelType.electric.defaultKWhPer100Miles ?? 30.0
            return (kwh / 100.0) * Car.gridCO2PerKWh
        }
    }

    // MARK: - Actions

    private func populateFromCar(_ car: Car) {
        name = car.name
        year = car.year.map { "\($0)" } ?? ""
        make = car.make ?? ""
        model = car.model ?? ""
        fuelType = car.fuelType
        mpgString = car.mpg.map { "\($0)" } ?? ""
        kWhString = car.kWhPer100Miles.map { "\($0)" } ?? ""
        co2Override = car.co2PerMileOverride.map { "\($0)" } ?? ""
        startDate = car.startDate
        hasEndDate = car.endDate != nil
        endDate = car.endDate ?? Date()
        isDefault = car.isDefault
        notes = car.notes
    }

    private func saveCar() {
        let car = Car(
            id: existingCar?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            year: Int(year),
            make: make.isEmpty ? nil : make,
            model: model.isEmpty ? nil : model,
            fuelType: fuelType,
            mpg: fuelType == .electric ? nil : Double(mpgString),
            kWhPer100Miles: fuelType == .electric ? Double(kWhString) : nil,
            co2PerMileOverride: Double(co2Override),
            startDate: startDate.startOfDay,
            endDate: hasEndDate ? endDate.startOfDay : nil,
            isDefault: isDefault,
            notes: notes
        )
        onSave(car)
        dismiss()
    }
}
