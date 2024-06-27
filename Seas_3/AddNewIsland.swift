//
//  AddNewIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData
import CoreLocation
import Combine

struct AddNewIsland: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var islandName = ""
    @State private var islandLocation = ""
    @State private var createdByUserId = ""
    @State private var gymWebsite: String = ""
    @State private var gymWebsiteURL: URL?

    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    
    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedProtocol = "http://"

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Island Details")) {
                    TextField("Island Name", text: $islandName)
                        .onChange(of: islandName) { _ in validateFields() }
                    TextField("Street", text: $street)
                        .onChange(of: street) { _ in
                            updateIslandLocation()
                            validateFields()
                        }
                    TextField("City", text: $city)
                        .onChange(of: city) { _ in
                            updateIslandLocation()
                            validateFields()
                        }
                    TextField("State", text: $state)
                        .onChange(of: state) { _ in
                            updateIslandLocation()
                            validateFields()
                        }
                    TextField("Zip", text: $zip)
                        .onChange(of: zip) { _ in
                            updateIslandLocation()
                            validateFields()
                        }
                }
                
                Section(header: Text("Instagram link/Facebook/Website (if applicable)")) {
                    Picker("Protocol", selection: $selectedProtocol) {
                        Text("http://").tag("http://")
                        Text("https://").tag("https://")
                        Text("ftp://").tag("ftp://")
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    TextField("Links", text: $gymWebsite, onEditingChanged: { _ in
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
                        validateFields()
                    })
                    .keyboardType(.URL)
                }
                
                Section(header: Text("Entered By")) {
                    TextField("Your Name", text: $createdByUserId)
                        .onChange(of: createdByUserId) { _ in validateFields() }
                }
                
                Button("Save") {
                    if isSaveEnabled {
                        print("Save button tapped")
                        geocodeIslandLocation()
                    } else {
                        print("Save button disabled")
                        print("Error: Required fields are empty or URL is invalid")
                    }
                }
                .disabled(!isSaveEnabled)
            }
            .navigationBarTitle("Add Gym/Dojo Here", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            validateFields() // Initial validation check
        }
    }
    
    private func updateIslandLocation() {
        islandLocation = "\(street), \(city), \(state) \(zip)"
        print("Updated Island Location: \(islandLocation)")
    }

    private func validateFields() {
        let isValid = !islandName.isEmpty &&
                      !street.isEmpty &&
                      !city.isEmpty &&
                      !state.isEmpty &&
                      !zip.isEmpty &&
                      !createdByUserId.isEmpty &&
                      (gymWebsite.isEmpty || validateURL(selectedProtocol + stripProtocol(from: gymWebsite)))
        print("islandName: \(islandName)")
        print("street: \(street)")
        print("city: \(city)")
        print("state: \(state)")
        print("zip: \(zip)")
        print("createdByUserId: \(createdByUserId)")
        print("gymWebsite: \(gymWebsite)")
        print("gymWebsiteURL: \(String(describing: gymWebsiteURL))")
        print("isValid: \(isValid)")
        
        isSaveEnabled = isValid // Update isSaveEnabled based on validation
    }

    private func clearFields() {
        islandName = ""
        islandLocation = ""
        createdByUserId = ""
        street = ""
        city = ""
        state = ""
        zip = ""
        gymWebsite = ""
        gymWebsiteURL = nil
    }
    
    private func geocodeIslandLocation() {
        let address = "\(street), \(city), \(state) \(zip)"
        print("Geocoding Island Location: \(address)")
        
        geocodeAddress(address) { result in
            switch result {
            case .success(let (latitude, longitude)):
                print("Geocoded coordinates - Latitude: \(latitude), Longitude: \(longitude)")
                guard !latitude.isNaN && !longitude.isNaN else {
                    print("Error: Invalid latitude (\(latitude)) or longitude (\(longitude))")
                    showAlert = true
                    alertMessage = "Failed to get valid coordinates for the island location."
                    return
                }
                assert(!latitude.isNaN, "Encountered NaN value for latitude")
                assert(!longitude.isNaN, "Encountered NaN value for longitude")
                saveIsland(latitude: latitude, longitude: longitude)
            case .failure(let error):
                print("Geocoding failed: \(error.localizedDescription)")
                showAlert = true
                alertMessage = "Failed to geocode the island location."
            }
        }
    }

    private func saveIsland(latitude: Double, longitude: Double) {
        let newIsland = PirateIsland(context: viewContext)
        newIsland.islandName = islandName
        newIsland.islandLocation = islandLocation
        newIsland.createdByUserId = createdByUserId
        newIsland.createdTimestamp = Date()
        
        // Validate latitude and longitude
        if latitude.isNaN || longitude.isNaN {
            print("Error: Invalid latitude (\(latitude)) or longitude (\(longitude))")
            showAlert = true
            alertMessage = "Invalid coordinates received. Please check the island location."
            return
        }
        
        assert(!latitude.isNaN, "Encountered NaN value for latitude")
        assert(!longitude.isNaN, "Encountered NaN value for longitude")
        
        newIsland.latitude = latitude
        newIsland.longitude = longitude
        newIsland.gymWebsite = gymWebsiteURL
        
        do {
            try viewContext.save()
            print("Successfully saved new island")
            clearFields() // Clear form after successful save
        } catch {
            print("Failed to save new island: \(error.localizedDescription)")
            showAlert = true
            alertMessage = "Failed to save the island. Please try again."
        }
    }

    private func validateURL(_ urlString: String) -> Bool {
        let urlPattern = #"^(https?:\/\/)?(www\.)?(facebook\.com|instagram\.com|[\w\-]+\.[\w\-]+)(\/[\w\-\.]*)*\/?$"#
        let result = NSPredicate(format: "SELF MATCHES %@", urlPattern).evaluate(with: urlString)
        print("URL Validation: \(urlString) is \(result ? "valid" : "invalid")")
        return result
    }

    private func stripProtocol(from urlString: String) -> String {
        var strippedString = urlString
        if let range = strippedString.range(of: "://") {
            strippedString = String(strippedString[range.upperBound...])
        }
        print("Stripped URL: \(strippedString)")
        return strippedString
    }
}

struct AddNewIsland_Previews: PreviewProvider {
    static var previews: some View {
        AddNewIsland()
    }
}
