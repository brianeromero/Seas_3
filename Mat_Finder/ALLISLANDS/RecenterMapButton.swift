//
//  RecenterMapButton.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/9/26.
//

import SwiftUI
import MapKit
import CoreLocation


struct RecenterMapButton: View {

    @ObservedObject var userLocationVM: UserLocationMapViewModel
    @State private var isOffCenter = false

    var body: some View {

        Group {

            if isOffCenter {

                Button {

                    guard let location = userLocationVM.userLocation,
                          let mapView = IslandMKMapView.sharedMapView
                    else { return }

                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    let region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: mapView.region.span
                    )

                    mapView.setRegion(region, animated: true)
                    isOffCenter = false

                } label: {

                    Image(systemName: "location.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }

        // EXISTING
        .onReceive(
            NotificationCenter.default.publisher(for: .mapRegionDidChange)
        ) { _ in
            checkIfMapMoved()
        }

        // 👇 ADD THIS HERE
        .onAppear {
            checkIfMapMoved()
        }
    }


    private func checkIfMapMoved() {

        guard let location = userLocationVM.userLocation,
              let mapView = IslandMKMapView.sharedMapView
        else { return }

        let center = mapView.region.center

        let centerLocation = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude
        )

        let distance = centerLocation.distance(from: location)

        // Show button if map moved more than ~150m
        withAnimation(.easeInOut(duration: 0.2)) {
            isOffCenter = distance > 150
        }
    }
}
