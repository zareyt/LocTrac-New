//
//  LocationManager.swift
//  LocTrac
//
//  Created by Tim Arey on 4/11/23.
//

import Foundation
import CoreLocation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var latitude: CLLocationDegrees = 0.0
    @Published var longitude: CLLocationDegrees = 0.0

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isRequestInFlight: Bool = false

    // Keep the original error if you need it internally
    @Published var error: Error?

    // Equatable proxy for SwiftUI observation
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private var timeoutWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        // Prime current status
        authorizationStatus = manager.authorizationStatus
    }

    // Public API to get one-shot current location with an explicit timeout
    func requestCurrentLocation(timeout: TimeInterval = 10) {
        error = nil
        errorMessage = nil

        // Ensure we’re authorized; if not, request it and wait for delegate callback
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startOneShotRequest(timeout: timeout)
        case .notDetermined:
            isRequestInFlight = true // show loading while user responds
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Surface an error immediately
            let nsErr = NSError(domain: "LocationManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Location access is denied or restricted. Enable it in Settings."
            ])
            self.error = nsErr
            self.errorMessage = nsErr.localizedDescription
        @unknown default:
            let nsErr = NSError(domain: "LocationManager", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Unknown authorization status."
            ])
            self.error = nsErr
            self.errorMessage = nsErr.localizedDescription
        }
    }

    private func startOneShotRequest(timeout: TimeInterval) {
        // Cancel any prior timeout
        timeoutWorkItem?.cancel()

        isRequestInFlight = true
        manager.requestLocation()

        // Install timeout fallback
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.isRequestInFlight {
                self.isRequestInFlight = false
                let nsErr = NSError(domain: "LocationManager", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Timed out fetching your location. Try again."
                ])
                self.error = nsErr
                self.errorMessage = nsErr.localizedDescription
            }
        }
        timeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        // If we were waiting on authorization, proceed when granted
        if isRequestInFlight {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                // Continue with the pending request
                startOneShotRequest(timeout: 10)
            case .denied, .restricted:
                isRequestInFlight = false
                let nsErr = NSError(domain: "LocationManager", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Location access is denied or restricted. Enable it in Settings."
                ])
                error = nsErr
                errorMessage = nsErr.localizedDescription
            case .notDetermined:
                // Still waiting; do nothing
                break
            @unknown default:
                isRequestInFlight = false
                let nsErr = NSError(domain: "LocationManager", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Unknown authorization status."
                ])
                error = nsErr
                errorMessage = nsErr.localizedDescription
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        timeoutWorkItem?.cancel()
        isRequestInFlight = false

        // Prefer the most recent valid fix
        guard let latest = locations.last else { return }
        location = latest
        latitude = latest.coordinate.latitude
        longitude = latest.coordinate.longitude

        // Clear any prior error on success
        error = nil
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        timeoutWorkItem?.cancel()
        isRequestInFlight = false
        self.error = error
        self.errorMessage = (error as NSError).localizedDescription
        // If we have a last known location in manager.location, publish it as a fallback
        if let fallback = manager.location {
            location = fallback
            latitude = fallback.coordinate.latitude
            longitude = fallback.coordinate.longitude
        }
    }
}

