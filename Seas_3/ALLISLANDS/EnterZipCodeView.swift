//
//  EnterZipCodeView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreLocation
import MapKit
import CoreData

struct EnterZipCodeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showPinModal = false
    @State private var showMap = false
    @State private var tappedLocation: CustomMapMarker?
    @StateObject private var viewModel: EnterZipCodeViewModel
    @State private var selectedIsland: PirateIsland?
    @State private var width: CGFloat = 100
    @State private var height: CGFloat = 100
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var selectedDay: DayOfWeek?

    init(viewModel: EnterZipCodeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack {
            TextField("Enter Address, location, or Zipcode", text: $viewModel.address)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            RadiusPicker(selectedRadius: $viewModel.currentRadius)
                .padding()

            Button("Search") {
                viewModel.fetchLocation(for: viewModel.address, selectedRadius: viewModel.currentRadius)
                showMap = true
            }
            .padding()

            if viewModel.hasLocationOrPirateIslands {
                Map(coordinateRegion: $viewModel.region, annotationItems: viewModel.annotationItems) { location in
                    MapAnnotation(coordinate: location.coordinate) {
                        VStack {
                            Text(location.title ?? "")
                                .font(.caption)
                                .padding(5)
                                .background(Color.white)
                                .cornerRadius(5)
                                .shadow(radius: 3)
                            Image(systemName: (location.pirateIsland?.id == viewModel.enteredLocation?.pirateIsland?.id) ? "pin.square.fill" : "mappin.circle.fill")
                                .foregroundColor((location.pirateIsland?.id == viewModel.enteredLocation?.pirateIsland?.id) ? .red : .blue)
                        }
                        .onTapGesture {
                            tappedLocation = location
                            showPinModal = true
                        }
                    }
                }
                .frame(height: 300)
                .padding()
            }
        }
        .onAppear {
            viewModel.locationManager.requestLocation()
        }
        .navigationBarTitle("Enter Address or Zip Code")
        .onChange(of: tappedLocation) { newTappedLocation in
            if let newTappedLocation = newTappedLocation {
                selectedIsland = newTappedLocation.pirateIsland
            }
        }
        .sheet(isPresented: $showPinModal) {
            if let tappedLocation = tappedLocation {
                IslandModalView(
                    customMapMarker: tappedLocation,
                    width: $width,
                    height: $height,
                    islandName: tappedLocation.title ?? "",
                    islandLocation: "\(tappedLocation.coordinate.latitude), \(tappedLocation.coordinate.longitude)",
                    formattedCoordinates: "",
                    createdTimestamp: Date().formatted(),
                    formattedTimestamp: "",
                    gymWebsite: nil,
                    reviews: [],
                    averageStarRating: "0",
                    dayOfWeekData: [],
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: AppDayOfWeekViewModel(repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared)),
                    selectedDay: $selectedDay,
                    showModal: .constant(false)
                )
            }
        }
    }
}

extension EnterZipCodeViewModel {
    var hasLocationOrPirateIslands: Bool {
        enteredLocation != nil || !pirateIslands.isEmpty
    }
    
    var annotationItems: [CustomMapMarker] {
        // Map each `CustomMapMarker` to a new `CustomMapMarker`
        let pirateIslandMarkers = pirateIslands.map { marker in
            CustomMapMarker(
                id: marker.id,
                coordinate: marker.coordinate,
                title: marker.title,
                pirateIsland: marker.pirateIsland
            )
        }

        // Create an array starting with the `enteredLocation` marker, if available
        var markers: [CustomMapMarker] = []
        if let location = enteredLocation {
            markers.append(CustomMapMarker(
                id: location.id,
                coordinate: location.coordinate,
                title: location.title,
                pirateIsland: location.pirateIsland
            ))
        }

        // Append the converted pirate island markers
        markers.append(contentsOf: pirateIslandMarkers)

        return markers
    }
}

#if DEBUG
struct EnterZipCodeView_Previews: PreviewProvider {
    static var previews: some View {
        EnterZipCodeView(viewModel: EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository(persistenceController: PersistenceController.preview),
            context: PersistenceController.preview.viewContext
        ))
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
#endif
