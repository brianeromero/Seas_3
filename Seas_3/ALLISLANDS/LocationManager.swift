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
    private var isAuthorized = false

    

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Start location services as needed
        startLocationServices()
    }

    func startLocationServices() {
        DispatchQueue.global(qos: .utility).async {
            if CLLocationManager.locationServicesEnabled() {
                self.locationManager.requestWhenInUseAuthorization()
            } else {
                print("Alert: Your location services are off and must be turned on.")
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

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        updateRegion()
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get user location: \(error.localizedDescription)")
        // Display a user alert or retry the location request
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            break
        case .restricted:
            print("Location restricted. Check Parent Controls.")
        case .denied:
            print("Enable location permissions in Settings.")
        case .authorizedAlways, .authorizedWhenInUse:
            guard !isAuthorized else { return }
            isAuthorized = true
            locationManager.startUpdatingLocation()
        default:
            print("Unknown authorization status.")
        }
    }

    private func updateRegion() {
        if let location = userLocation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: MapDetails.defaultSpan.latitudeDelta,
                    longitudeDelta: MapDetails.defaultSpan.longitudeDelta
                )
            )
        }
    }


    func getCurrentUserLocation() -> CLLocation? {
        return userLocation
    }

    func calculateDistance(from startLocation: CLLocation, to endLocation: CLLocation) -> CLLocationDistance {
        return startLocation.distance(from: endLocation)
    }
}
