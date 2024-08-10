//
// AllEnteredLocations.swift
// Seas2
//
// Created by Brian Romero on 6/17/24.
import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct AllEnteredLocations: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: AllEnteredLocationsViewModel

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: AllEnteredLocationsViewModel(dataManager: PirateIslandDataManager(viewContext: context)))
    }

    var body: some View {
        NavigationView {
            VStack {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.pirateMarkers.isEmpty {
                    Text("No Open Mats found.")
                        .padding()
                } else {
                    Map(coordinateRegion: $viewModel.region, annotationItems: viewModel.pirateMarkers) { location in
                        MapAnnotation(coordinate: location.coordinate) {
                            VStack {
                                Text(location.title)
                                    .font(.caption)
                                    .padding(5)
                                    .background(Color.white)
                                    .cornerRadius(5)
                                    .shadow(radius: 3)
                                CustomMarkerView()
                            }
                        }
                    }
                    .onAppear {
                        viewModel.logTileInformation()
                    }
                }
            }
            .navigationTitle("All Open Mats Map")
            .onAppear {
                viewModel.fetchPirateIslands()
            }
        }
    }
}

struct AllEnteredLocations_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.viewContext
        
        return AllEnteredLocations(context: context)
            .environment(\.managedObjectContext, context)
            .previewDisplayName("All Entered Locations Preview")
    }
}
