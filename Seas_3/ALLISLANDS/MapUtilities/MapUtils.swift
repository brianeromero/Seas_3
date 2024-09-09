//
//  MapUtils.swift
//  Seas_3
//
//  Created by Brian Romero on 9/3/24.
//

import Foundation
import SwiftUI
import MapKit

struct MapUtils {
    private static let metersToMilesConversionFactor = 0.000621371
    
    private static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) * metersToMilesConversionFactor
    }
    
    static func fetchLocation(for address: String, selectedRadius: Double, retryCount: Int = 0, completion: @escaping (CLLocationCoordinate2D?, Error?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                
                if retryCount < 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(retryCount) * 0.5) {
                        fetchLocation(for: address, selectedRadius: selectedRadius, retryCount: retryCount + 1, completion: completion)
                    }
                } else {
                    completion(nil, error)
                }
                return
            }
            
            guard let placemark = placemarks?.first, let location = placemark.location else {
                print("No placemarks found for address: \(address)")
                completion(nil, NSError(domain: "GeocodingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No results found for the address provided."]))
                return
            }
            
            completion(location.coordinate, nil)
        }
    }
    
    static func updateRegion(markers: [CustomMapMarker], selectedRadius: Double, center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let latitudeDelta = selectedRadius / 69.0
        let longitudeDelta = selectedRadius / (69.0 * cos(center.latitude * .pi / 180))
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta))
    }
    
    static func updateRegionWithRadiusChange(markers: [CustomMapMarker], selectedRadius: Double, center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        return updateRegion(markers: markers, selectedRadius: selectedRadius, center: center)
    }
    
    private static func calculateCenter(from markers: [CustomMapMarker]) -> CLLocationCoordinate2D {
        let sumLatitude = markers.reduce(0) { $0 + $1.coordinate.latitude }
        let sumLongitude = markers.reduce(0) { $0 + $1.coordinate.longitude }
        
        return CLLocationCoordinate2D(latitude: sumLatitude / Double(markers.count), longitude: sumLongitude / Double(markers.count))
    }
    
    static func calculateRegionToFit(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                      span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360))
        }

        let minLatitude = coordinates.map { $0.latitude }.min() ?? 0
        let maxLatitude = coordinates.map { $0.latitude }.max() ?? 0
        let minLongitude = coordinates.map { $0.longitude }.min() ?? 0
        let maxLongitude = coordinates.map { $0.longitude }.max() ?? 0

        let centerLatitude = (minLatitude + maxLatitude) / 2
        let centerLongitude = (minLongitude + maxLongitude) / 2
        let center = CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)

        let latitudeDelta = maxLatitude - minLatitude
        let longitudeDelta = maxLongitude - minLongitude

        let span = MKCoordinateSpan(latitudeDelta: latitudeDelta * 1.2, longitudeDelta: longitudeDelta * 1.2)

        return MKCoordinateRegion(center: center, span: span)
    }

    // Add the setMapRegion function here
    static func setMapRegion(mapView: MKMapView, centerCoordinate: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        let maxDelta: CLLocationDegrees = 180.0
        let validSpan = MKCoordinateSpan(latitudeDelta: min(maxDelta, abs(span.latitudeDelta)),
                                         longitudeDelta: min(maxDelta, abs(span.longitudeDelta)))
        
        let region = MKCoordinateRegion(center: centerCoordinate, span: validSpan)
        mapView.setRegion(region, animated: true)
    }
}
