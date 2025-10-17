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

    @Published var region = MKCoordinateRegion(
        center: MapDetails.startingLocation,
        span: MapDetails.defaultSpan
    )
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private var retryCount = 0
    private let maxRetries = 3

    private override init() {
        super.init()
        print("🧭 UserLocationMapViewModel initialized (singleton instance).")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func startLocationServices() {
        guard CLLocationManager.locationServicesEnabled() else {
            print("⚠️ Location services are disabled.")
            return
        }

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("📍 Requesting location authorization…")
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Already authorized, requesting location…")
            locationManager.requestLocation()

        case .restricted, .denied:
            print("🚫 Location access restricted or denied.")

        @unknown default:
            print("⚠️ Unknown authorization status.")
        }
    }



    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            print("Location services not authorized")
            return
        }
        locationManager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus  // ✅ keep in sync
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Authorized — now requesting location.")
            manager.requestLocation()
        case .denied:
            print("⚠️ Location access denied.")
        case .restricted:
            print("⚠️ Location access restricted.")
        case .notDetermined:
            print("ℹ️ Authorization not yet determined.")
        @unknown default:
            print("⚠️ Unknown authorization status.")
        }
    }



    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        print("Updated location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        userLocation = location
        updateRegion()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")

        // Retry logic
        if retryCount < maxRetries {
            retryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.locationManager.requestLocation()
            }
        } else {
            retryCount = 0
        }
    }

    // MARK: - Helpers

    private func updateRegion() {
        guard let location = userLocation else { return }
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: MapDetails.defaultSpan.latitudeDelta,
                longitudeDelta: MapDetails.defaultSpan.longitudeDelta
            )
        )
    }

    func getCurrentUserLocation() -> CLLocation? {
        return userLocation
    }

    func calculateDistance(from startLocation: CLLocation, to endLocation: CLLocation) -> CLLocationDistance {
        return startLocation.distance(from: endLocation)
    }
}
