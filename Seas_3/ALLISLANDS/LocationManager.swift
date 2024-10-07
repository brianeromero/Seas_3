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
                switch self.locationManager.authorizationStatus {
                case .notDetermined:
                    DispatchQueue.main.async {
                        self.locationManager.requestWhenInUseAuthorization()
                    }
                case .authorizedWhenInUse, .authorizedAlways:
                    self.locationManager.requestLocation()
                case .restricted, .denied:
                    print("Location services are restricted or denied.")
                @unknown default:
                    print("Unknown authorization status.")
                }
            } else {
                print("Alert: Your location services are off and must be turned on.")
            }
        }
    }
    
    
    func requestLocation() {
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
        let errorCode = (error as? CLError)?.code ?? .locationUnknown
        switch errorCode {
        case .denied:
            print("Location services are denied.")
        case .locationUnknown:
            print("Location unknown.")
        case .network:
            print("Network error.")
        case .geocodeFoundNoResult, .geocodeFoundPartialResult, .geocodeCanceled:
            print("Geocode error.")
        default:
            print("Failed to get user location: \(error.localizedDescription)")
        }
        
        // Retry location request after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.locationManager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .restricted, .denied:
            print("Location services are restricted or denied.")
        default:
            print("Unknown authorization status.")
        }
    }

    
    deinit {
        locationManager.delegate = nil
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
