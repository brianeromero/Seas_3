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

class UserLocationMapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion(
        center: MapDetails.startingLocation,
        span: MapDetails.defaultSpan
    )
    @Published var userLocation: CLLocation?
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Start location services as needed
        startLocationServices()
    }

    func startLocationServices() {
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                DispatchQueue.main.async {
                    self.locationManager.requestWhenInUseAuthorization()
                }
            } else {
                DispatchQueue.main.async {
                    print("Alert: Your location services are off and must be turned on.")
                }
            }
        }
    }

    func requestLocation() {
        // Ensure the authorization status is handled correctly
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        } else {
            print("Location services are not authorized.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.userLocation = location
            self.updateRegion()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get user location: \(error.localizedDescription)")
        // Additional error handling or user alert can be added here
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            switch manager.authorizationStatus {
            case .notDetermined:
                self.locationManager.requestWhenInUseAuthorization()
            case .restricted:
                print("Your location appears to be restricted - perhaps due to Parent Controls.")
            case .denied:
                print("You have denied this app's location permissions. Go into settings to change this.")
            case .authorizedAlways, .authorizedWhenInUse:
                self.locationManager.startUpdatingLocation()
                self.requestLocation() // Optionally request location if needed
            @unknown default:
                print("Unknown authorization status.")
            }
        }
    }

    private func updateRegion() {
        if let location = userLocation {
            DispatchQueue.main.async {
                self.region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MapDetails.defaultSpan
                )
            }
        }
    }


    func getCurrentUserLocation() -> CLLocation? {
        return userLocation
    }

    func calculateDistance(from startLocation: CLLocation, to endLocation: CLLocation) -> CLLocationDistance {
        return startLocation.distance(from: endLocation)
    }
}
