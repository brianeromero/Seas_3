//
//  AddIslandFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData
import Combine
import CoreLocation
import Foundation

struct AddIslandFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    @Binding var islandName: String
    @Binding var islandLocation: String
    @State private var street: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zip: String = ""
    @State private var neighborhood: String = ""
    @State private var complement: String = ""
    @State private var apartment: String = ""
    @State private var additionalInfo: String = ""
    @Binding var createdByUserId: String
    @Binding var gymWebsite: String
    @Binding var selectedCountry: Country?
    @Binding var gymWebsiteURL: URL?

    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isGeocoding = false

    @StateObject var pirateIslandViewModel = PirateIslandViewModel(persistenceController: PersistenceController.shared)
    @State private var currentIsland: PirateIsland

    init(
        currentIsland: PirateIsland,
        islandName: Binding<String>,
        islandLocation: Binding<String>,
        createdByUserId: Binding<String>,
        gymWebsite: Binding<String>,
        gymWebsiteURL: Binding<URL?>,
        selectedCountry: Binding<Country?>
    ) {
        self._currentIsland = State(wrappedValue: currentIsland)
        self._islandName = islandName
        self._islandLocation = islandLocation
        self._createdByUserId = createdByUserId
        self._gymWebsite = gymWebsite
        self._gymWebsiteURL = gymWebsiteURL
        self._selectedCountry = selectedCountry
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Gym Details")) {
                    TextField("Gym Name", text: $islandName)
                        .onChange(of: islandName) { _ in validateFields() }
                    
                    UnifiedCountryPickerView(selectedCountry: $selectedCountry)

                    AddressFieldsView(
                        selectedCountry: $selectedCountry,
                        street: $street,
                        city: $city,
                        state: $state,
                        zip: $zip,
                        neighborhood: $neighborhood,
                        complement: $complement,
                        apartment: $apartment,
                        additionalInfo: $additionalInfo
                    )
                    
                    TextField("Full Address", text: $islandLocation)
                        .onChange(of: islandLocation) { _ in validateFields() }
                }

                Section(header: Text("Entered By")) {
                    TextField("Your Name", text: $createdByUserId)
                        .onChange(of: createdByUserId) { newValue in
                            Logger.logCreatedByIdEvent(createdByUserId: newValue, fileName: "AddIslandFormView", functionName: "TextField.onChange")
                            validateFields()
                        }
                }

                Section(header: Text("Website (if applicable)")) {
                    TextField("Website", text: $gymWebsite)
                        .onChange(of: gymWebsite) { newValue in
                            gymWebsiteURL = URL(string: newValue)
                            validateFields()
                        }
                }
            }
            .navigationTitle("Add Gym")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isSaveEnabled {
                            Task {
                                try await saveIslandData()
                            }
                        } else {
                            alertMessage = "Required fields are empty or invalid"
                            showAlert.toggle()
                        }
                    }
                    .disabled(!isSaveEnabled)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Invalid Input"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                validateFields()
            }
        }
    }
    
    private func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private func getAddressFields(for country: String) -> [AddressFieldType] {
        // Retrieve the address fields for the selected country from the addressFieldRequirements dictionary
        let fields = addressFieldRequirements[country] ?? defaultAddressFieldRequirements
        
        // Log the country and the corresponding fields
        if addressFieldRequirements[country] != nil {
            print("Country: \(country), Custom Fields: \(fields.map { $0.rawValue })") // Log custom fields for known countries
        } else {
            print("Country: \(country), Using Default Fields: \(fields.map { $0.rawValue })") // Log default fields
        }
        
        return fields
    }

    func updateIslandLocation() {
        isGeocoding = true
        Task {
            do {
                // Construct the address string dynamically based on selected country
                var addressComponents = [String]()
                
                // Get the address fields for the selected country
                let requiredFields = getAddressFields(for: selectedCountry?.name.common ?? "US")
                
                // Append the relevant address components
                if requiredFields.contains(.street) {
                    addressComponents.append(street)
                }
                if requiredFields.contains(.city) {
                    addressComponents.append(city)
                }
                if requiredFields.contains(.state) || requiredFields.contains(.province) {
                    addressComponents.append(state)
                }
                if requiredFields.contains(.postalCode) || requiredFields.contains(.pincode) || requiredFields.contains(.zip) {
                    addressComponents.append(zip)
                }
                if requiredFields.contains(.neighborhood) {
                    addressComponents.append(neighborhood)
                }
                if requiredFields.contains(.complement) {
                    addressComponents.append(complement)
                }
                if requiredFields.contains(.apartment) {
                    addressComponents.append(apartment)
                }
                if requiredFields.contains(.additionalInfo) {
                    addressComponents.append(additionalInfo)
                }
                
                // Create the full address string
                let location = addressComponents.joined(separator: ", ")
                
                // Attempt to geocode the location
                let coordinates = try await pirateIslandViewModel.geocodeAddress(location)
                
                // Update the island's coordinates
                currentIsland.latitude = coordinates.latitude
                currentIsland.longitude = coordinates.longitude
                
                // Save changes to Core Data
                try await viewContext.save()
                
                islandLocation = location  // Update the island location field
                validateFields()  // Validate after updating the location
            } catch {
                alertMessage = "Error with geocoding: \(error.localizedDescription)"
                showAlert.toggle()
            }
            isGeocoding = false
        }
    }

    private func validateFields() {
        Logger.logCreatedByIdEvent(createdByUserId: createdByUserId, fileName: "AddIslandFormView", functionName: "validateFields")
        let (isSaveEnabled, alertMessage) = ValidationUtility.validateIslandForm(
            islandName: islandName,
            street: street,
            city: city,
            state: state,
            zip: zip,
            selectedCountry: selectedCountry,
            createdByUserId: createdByUserId,
            gymWebsite: gymWebsite
        )
        self.alertMessage = alertMessage
        self.isSaveEnabled = isSaveEnabled
    }
    
    
    private func saveIslandData() async throws {
        do {
            // Save the single `islandLocation` field along with other data
            currentIsland.islandName = islandName
            currentIsland.islandLocation = islandLocation
            Logger.logCreatedByIdEvent(createdByUserId: createdByUserId, fileName: "AddIslandFormView", functionName: "saveIslandData")
            currentIsland.createdByUserId = createdByUserId
            currentIsland.gymWebsite = gymWebsiteURL

            // Save changes to Core Data
            try viewContext.save()

            // Dismiss the view after successful save
            presentationMode.wrappedValue.dismiss()
        } catch {
            alertMessage = "Error saving island data: \(error.localizedDescription)"
            showAlert.toggle()
        }
    }

}

struct AddIslandFormView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext

        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Gym"
        mockIsland.islandLocation = "123 Mock Street, Mock City, Mock State, 12345"
        mockIsland.createdByUserId = "Admin"
        mockIsland.gymWebsite = URL(string: "https://mockgym.com")
        mockIsland.country = "Mock Country"

        return AddIslandFormView(
            currentIsland: mockIsland,
            islandName: .constant("Mock Gym"),
            islandLocation: .constant("123 Mock Street, Mock City, Mock State, 12345"),
            createdByUserId: .constant("Admin"),
            gymWebsite: .constant("https://mockgym.com"),
            gymWebsiteURL: .constant(URL(string: "https://mockgym.com")),
            selectedCountry: .constant(nil)
        )
        .environment(\.managedObjectContext, context)
    }
}
