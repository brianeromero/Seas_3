//
//  LocationManager.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine

final class UserLocationMapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    static let shared = UserLocationMapViewModel() // Singleton

    // MARK: - Published Properties
    @Published var region = MKCoordinateRegion(
        center: MapDetails.startingLocation,
        span: MapDetails.defaultSpan
    )
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var hasStarted = false
    
    // Prevent multiple location requests
    @Published private(set) var hasRequestedLocation = false

    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var retryCount = 0
    private let maxRetries = 3

    // MARK: - Initialization
    private override init() {
        super.init()
        print("🧭 UserLocationMapViewModel initialized (singleton instance).")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - Start Services
    func startLocationServices() {
        guard !self.hasStarted else {
            print("🧭 Location services already started, skipping duplicate call.")
            // Still check authorization once
            locationManagerDidChangeAuthorization(locationManager)
            return
        }
        self.hasStarted = true
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        if authorizationStatus == .notDetermined {
            print("ℹ️ Authorization not determined — requesting WhenInUse permission.")
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManagerDidChangeAuthorization(locationManager)
        }
    }

    // MARK: - Location Requests
    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            print("⚠️ Location services not authorized")
            return
        }
        guard !hasRequestedLocation else { return }
        
        hasRequestedLocation = true
        locationManager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.requestLocation()
            case .denied:
                print("🚫 Location access denied.")
                self.promptToEnableLocationInSettings()
            case .restricted:
                print("⚠️ Location access restricted.")
            case .notDetermined:
                print("ℹ️ Authorization not yet determined.")
            @unknown default:
                print("⚠️ Unknown authorization status.")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        retryCount = 0 // reset retry count on success
        print("📍 Updated location: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.userLocation = location
            self.updateRegion()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Failed to get location: \(error.localizedDescription)")

        if retryCount < maxRetries {
            retryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self else { return }
                print("🔁 Retrying location request (\(self.retryCount)/\(self.maxRetries))...")
                self.locationManager.requestLocation()
            }
        } else {
            print("⛔️ Max retry attempts reached. Stopping further requests.")
            retryCount = 0
        }
    }

    // MARK: - Helpers
    private func updateRegion() {
        guard let location = userLocation else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MapDetails.defaultSpan
            )
        }
    }

    func getCurrentUserLocation() -> CLLocation? {
        userLocation
    }

    func calculateDistance(from startLocation: CLLocation, to endLocation: CLLocation) -> CLLocationDistance {
        startLocation.distance(from: endLocation)
    }

    private func promptToEnableLocationInSettings() {
        print("⚙️ Prompting user to enable location in Settings.")
        // Optional: trigger SwiftUI alert to guide user to Settings
    }
}
