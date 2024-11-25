//
//  EditExistingIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData

struct EditExistingIsland: View {
    @ObservedObject var island: PirateIsland
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var islandName: String
    @State private var islandLocation: String
    @State private var createdByUserId: String
    @State private var gymWebsite: String
    @State private var selectedProtocol = "https://"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var gymWebsiteURL: URL?
    @State private var lastModifiedByUserId: String

    init(island: PirateIsland, islandViewModel: PirateIslandViewModel) {
        self.island = island
        self.islandViewModel = islandViewModel
        _islandName = State(initialValue: island.islandName ?? "")
        _islandLocation = State(initialValue: island.islandLocation ?? "")
        _createdByUserId = State(initialValue: island.createdByUserId ?? "")
        _gymWebsite = State(initialValue: island.gymWebsite?.absoluteString ?? "")
        _lastModifiedByUserId = State(initialValue: island.lastModifiedByUserId ?? "")
    }
    
    var body: some View {
        Form {
            Section(header: Text("Gym Details")) {
                TextField("Gym Name", text: $islandName)
                TextField("Gym Location", text: $islandLocation)
                TextField("Last Modified By", text: $lastModifiedByUserId)
                TextField("Entered By", text: $createdByUserId)
                    .disabled(true)
                    .foregroundColor(.gray)
            }

            Section(header: Text("Instagram link/Facebook/Website (if applicable)")) {
                Picker("Protocol", selection: $selectedProtocol) {
                    Text("http://").tag("http://")
                    Text("https://").tag("https://")
                    Text("ftp://").tag("ftp://")
                }
                .pickerStyle(SegmentedPickerStyle())

                TextField("Links", text: $gymWebsite, onEditingChanged: { _ in
                    DispatchQueue.main.async {
                        if !gymWebsite.isEmpty {
                            let strippedURL = stripProtocol(from: gymWebsite)
                            let fullURLString = selectedProtocol + strippedURL

                            if validateURL(fullURLString) {
                                gymWebsiteURL = URL(string: fullURLString)
                            } else {
                                showAlert = true
                                alertMessage = "Invalid link entry"
                                gymWebsite = ""
                                gymWebsiteURL = nil
                            }
                        } else {
                            gymWebsiteURL = nil
                        }
                    }
                })
                .keyboardType(.URL)
            }
        }
        .navigationTitle("Edit Gym")
        .navigationBarItems(trailing:
            Button("Save") {
                saveIsland()
                presentationMode.wrappedValue.dismiss()
            }
        )
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Alert"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func saveIsland() {
        guard !islandName.isEmpty, !islandLocation.isEmpty, !lastModifiedByUserId.isEmpty else {
            showAlert = true
            alertMessage = "Please fill in all required fields"
            return
        }
        
        Task {
            do {
                // Geocode the address
                let coordinates = try await geocode(address: islandLocation, apiKey: GeocodingConfig.apiKey)
                
                // Update latitude and longitude
                try await islandViewModel.updatePirateIslandLatitudeLongitude(
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude,
                    island: island
                )
                print("Latitude/Longitude updated successfully")
                
                // Update the pirate island details
                await islandViewModel.updatePirateIsland(
                    island: island,
                    name: islandName,
                    location: islandLocation,
                    lastModifiedByUserId: lastModifiedByUserId,
                    gymWebsiteURL: gymWebsiteURL) { result in
                        switch result {
                        case .success:
                            print("Gym updated successfully")
                        case .failure(let error):
                            print("Error updating gym: \(error.localizedDescription)")
                        }
                    }
                // Dismiss the view
                presentationMode.wrappedValue.dismiss()
                
            } catch {
                // Handle errors
                showAlert = true
                alertMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func stripProtocol(from urlString: String) -> String {
        let protocols = ["http://", "https://", "ftp://"]
        var strippedURL = urlString
        for proto in protocols {
            if strippedURL.starts(with: proto) {
                strippedURL = String(strippedURL.dropFirst(proto.count))
                break
            }
        }
        return strippedURL
    }
    
    private func validateURL(_ urlString: String) -> Bool {
        if let url = URL(string: urlString) {
            return UIApplication.shared.canOpenURL(url)
        }
        return false
    }
}

// EditExistingIsland_Previews definition
struct EditExistingIsland_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        
        let island = PirateIsland(context: context)
        island.islandName = "Sample Gym"
        island.islandLocation = "123 Main St, City, State, 12345"
        island.createdByUserId = "UserCreated"
        island.lastModifiedByUserId = "" // Set lastModifiedByUserId for preview
        island.gymWebsite = URL(string: "https://www.example.com")
        
        let viewModel = PirateIslandViewModel(persistenceController: PersistenceController.shared)
        
        return NavigationView {
            EditExistingIsland(island: island, islandViewModel: viewModel)
                .environment(\.managedObjectContext, context)
        }
    }
}
