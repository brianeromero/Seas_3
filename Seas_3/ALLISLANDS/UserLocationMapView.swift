//
//  UserLocationMapView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/27/24.
//

import Foundation
import SwiftUI
import MapKit

struct UserLocationMapView: View {
    @ObservedObject var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        Map(coordinateRegion: $region, showsUserLocation: true)
            .onAppear {
                updateRegion()
            }
            .onChange(of: locationManager.userLocation) { _ in
                updateRegion()
            }
    }

    private func updateRegion() {
        if let location = locationManager.userLocation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
}

struct UserLocationMapView_Previews: PreviewProvider {
    static var previews: some View {
        UserLocationMapView()
    }
}
