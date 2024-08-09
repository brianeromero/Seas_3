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
    @ObservedObject var viewModel: EnterZipCodeViewModel

    @State private var showMap = false

    var body: some View {
        VStack {
            TextField("Enter Address", text: $viewModel.address)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // Bind selectedRadius to viewModel.currentRadius
            RadiusPicker(selectedRadius: $viewModel.currentRadius)
                .padding()

            Button("Search") {
                viewModel.fetchLocation(for: viewModel.address, selectedRadius: viewModel.currentRadius)
                showMap = true
            }
            .padding()

            if viewModel.enteredLocation != nil || !viewModel.pirateIslands.isEmpty {
                Map(coordinateRegion: $viewModel.region, annotationItems: [viewModel.enteredLocation].compactMap { $0 } + viewModel.pirateIslands) { location in
                    MapAnnotation(coordinate: location.coordinate) {
                        VStack {
                            Text(location.title)
                                .font(.caption)
                                .padding(5)
                                .background(Color.white)
                                .cornerRadius(5)
                                .shadow(radius: 3)
                            Image(systemName: location.id == viewModel.enteredLocation?.id ? "pin.square.fill" : "mappin.circle.fill")
                                .foregroundColor(location.id == viewModel.enteredLocation?.id ? .red : .blue)
                        }
                    }
                }
                .frame(height: 300) // Adjust as needed
                .padding()
            }
        }
        .onAppear {
            viewModel.locationManager.requestLocation()
        }
        .navigationBarTitle("Enter Address or Zip Code")
    }
}

#if DEBUG
struct EnterZipCodeView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext
        let repository = AppDayOfWeekRepository(persistenceController: persistenceController)
        let viewModel = EnterZipCodeViewModel(repository: repository, context: context)
        
        return EnterZipCodeView(viewModel: viewModel)
            .environment(\.managedObjectContext, context)
    }
}
#endif
