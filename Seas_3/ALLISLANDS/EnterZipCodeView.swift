//
//  EnterZipCodeView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreLocation
import MapKit
import CoreData

struct EnterZipCodeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var centerCoordinate = CLLocationCoordinate2D()
    @State private var enteredLocation: CustomMapMarker?
    @State private var pirateIslands: [CustomMapMarker] = []
    @State private var showMap = false
    @State private var address = ""
    @State private var selectedRadius: Double = 5.0

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        VStack {
            TextField("Enter Address", text: $address)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // Add radius picker here
            RadiusPicker(selectedRadius: $selectedRadius)
                .padding()

            Button("Search") {
                fetchLocation(for: address)
            }
            .padding()

            // Show the map if locations are available
            if showMap {
                Map(coordinateRegion: $region, annotationItems: [enteredLocation].compactMap { $0 } + pirateIslands) { location in
                    MapAnnotation(coordinate: location.coordinate) {
                        VStack {
                            Text(location.title)
                                .font(.caption)
                                .padding(5)
                                .background(Color.white)
                                .cornerRadius(5)
                                .shadow(radius: 3)
                            Image(systemName: location.id == enteredLocation?.id ? "pin.square.fill" : "mappin.circle.fill")
                                .foregroundColor(location.id == enteredLocation?.id ? .red : .blue)
                        }
                    }
                }
                .frame(height: 300)
                .padding()
                .onAppear {
                    if let location = enteredLocation?.coordinate {
                        updateRegion(location: location, radius: selectedRadius)
                    }
                }
                .onChange(of: selectedRadius) { newRadius in
                    if let location = enteredLocation?.coordinate {
                        updateRegion(location: location, radius: newRadius)
                        fetchPirateIslandsNear(location, within: newRadius * 1609.34) // Convert miles to meters
                    }
                }
            }
        }
        .navigationBarTitle("Enter Address or Zip Code")
    }

    private func fetchLocation(for address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                return
            }

            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("No location found")
                return
            }

            print("Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            let newMarker = CustomMapMarker(coordinate: location.coordinate, title: address)
            self.enteredLocation = newMarker
            self.showMap = true // Show map after fetching location
            self.fetchPirateIslandsNear(location.coordinate, within: selectedRadius * 1609.34) // Convert miles to meters
            self.updateRegion(location: location.coordinate, radius: selectedRadius)
        }
    }

    private func fetchPirateIslandsNear(_ location: CLLocationCoordinate2D, within distance: Double) {
        let results = PirateIsland.fetchIslandsNear(location: location, within: distance, in: viewContext)
        self.pirateIslands = results.compactMap { island in
            guard let title = island.islandName else {
                return nil
            }
            
            // Directly access latitude and longitude since they are Double (non-optional)
            let latitude = island.latitude
            let longitude = island.longitude
            
            // Ensure latitude and longitude are valid
            if latitude == 0.0 && longitude == 0.0 {
                print("Invalid latitude or longitude for island \(island)")
                return nil
            }
            
            return CustomMapMarker(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), title: title)
        }
        
        // Logging pirate islands fetched
        print("Fetched Pirate Islands: \(pirateIslands.count)")
    }


    private func updateRegion(location: CLLocationCoordinate2D, radius: Double) {
        // Calculate the span based on radius
        let span = MKCoordinateSpan(latitudeDelta: radius / 69.0, longitudeDelta: radius / 69.0)
        // Update the map region
        region = MKCoordinateRegion(center: location, span: span)
        
        // Logging updated region
        print("Updated Map Region: Center - \(location.latitude), \(location.longitude), Span - \(span.latitudeDelta), \(span.longitudeDelta)")
    }
}

#if DEBUG
struct EnterZipCodeView_Previews: PreviewProvider {
    static var previews: some View {
        EnterZipCodeView()
    }
}
#endif
