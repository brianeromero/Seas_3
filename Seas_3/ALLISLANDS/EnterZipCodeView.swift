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
                createMapView()
            }
        }
        .onAppear {
            viewModel.locationManager.requestLocation()
        }
        .navigationBarTitle("Enter Address or Zip Code")
        .onChange(of: tappedLocation) { newTappedLocation in
            if let pirateIsland = newTappedLocation?.pirateIsland {
                self.selectedIsland = pirateIsland
            }
        }
        .sheet(isPresented: $showPinModal) {
            createIslandModalView()
        }
    }

    private func createMapView() -> some View {
        Map(coordinateRegion: $viewModel.region, annotationItems: viewModel.annotationItems) { location in
            MapAnnotation(coordinate: location.coordinate) {
                annotationView(for: location)
            }
        }
        .frame(height: 300)
        .padding()
    }

    private func annotationView(for location: CustomMapMarker) -> some View {
        VStack {
            Text(location.title ?? "")
                .font(.caption)
                .padding(5)
                .background(Color.white)
                .cornerRadius(5)
                .shadow(radius: 3)

            Image(systemName: pinImageName(for: location))
                .foregroundColor(pinColor(for: location))
        }
        .onTapGesture {
            tappedLocation = location
            showPinModal = true
        }
    }

    private func pinImageName(for location: CustomMapMarker) -> String {
        location.pirateIsland?.id == viewModel.enteredLocation?.pirateIsland?.id ? "pin.square.fill" : "mappin.circle.fill"
    }

    private func pinColor(for location: CustomMapMarker) -> Color {
        location.pirateIsland?.id == viewModel.enteredLocation?.pirateIsland?.id ? .red : .blue
    }
    
    @ViewBuilder
    private func createIslandModalView() -> some View {
        if let tappedLocation = tappedLocation {
            if let pirateIsland = tappedLocation.pirateIsland {
                IslandModalView(
                    customMapMarker: tappedLocation,
                    width: .constant(300),
                    height: .constant(500),
                    islandName: pirateIsland.name ?? "",
                    islandLocation: pirateIsland.islandLocation ?? "",
                    formattedCoordinates: pirateIsland.formattedCoordinates,
                    createdTimestamp: DateFormat.full.string(from: pirateIsland.createdTimestamp),
                    formattedTimestamp: DateFormat.full.string(from: pirateIsland.lastModifiedTimestamp ?? Date()),
                    gymWebsite: pirateIsland.gymWebsite,
                    reviews: ReviewUtils.getReviews(from: pirateIsland.reviews),
                    averageStarRating: ReviewUtils.averageStarRating(for: ReviewUtils.getReviews(from: pirateIsland.reviews)),
                    dayOfWeekData: pirateIsland.daysOfWeekArray.compactMap { DayOfWeek(rawValue: $0.day ?? "") },
                    selectedAppDayOfWeek: .constant(nil),
                    selectedIsland: $selectedIsland,
                    viewModel: AppDayOfWeekViewModel(repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared)),
                    selectedDay: .constant(.monday),
                    showModal: $showPinModal
                )
            } else {
                Text("No Pirate Island Selected")
                    .padding()
            }
        } else {
            Text("No Location Selected")
                .padding()
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
