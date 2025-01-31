//  EditExistingIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData
import Combine
import FirebaseFirestore
import os

struct EditExistingIsland: View {
    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Observed Objects
    @ObservedObject var island: PirateIsland
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @StateObject var islandDetails = IslandDetails()
    @StateObject private var countryService = CountryService()
    @State private var isCountryPickerPresented = false

    // MARK: - State Variables
    @State private var isSaveEnabled: Bool = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var gymWebsite: String
    @State private var islandName: String
    @State private var islandLocation: String
    @State private var lastModifiedByUserId: String
    @State private var selectedCountry: Country? = nil
    @State private var requiredAddressFields: [AddressFieldType] = defaultAddressFieldRequirements

    @State private var createdByUserId: String
    @State private var selectedProtocol = "https://"
    @State private var gymWebsiteURL: URL?

    // MARK: - Initialization
    init(island: PirateIsland, islandViewModel: PirateIslandViewModel, profileViewModel: ProfileViewModel) {
        self.island = island
        self.islandViewModel = islandViewModel
        self.profileViewModel = profileViewModel
        _islandName = State(initialValue: island.islandName ?? "")
        _islandLocation = State(initialValue: island.islandLocation ?? "")
        _lastModifiedByUserId = State(initialValue: island.lastModifiedByUserId ?? "")
        _createdByUserId = State(initialValue: island.createdByUserId ?? "")
        _gymWebsite = State(initialValue: island.gymWebsite?.absoluteString ?? "")
        _islandDetails = StateObject(wrappedValue: IslandDetails(
            islandName: island.islandName ?? "",
            street: "", // Replace with actual value if available
            city: "", // Replace with actual value if available
            state: "", // Replace with actual value if available
            postalCode: "", // Replace with actual value if available
            latitude: nil, // Replace with actual latitude if available
            longitude: nil, // Replace with actual longitude if available
            selectedCountry: nil, // Replace with actual country if available
            additionalInfo: "", // Replace with actual value if available
            requiredAddressFields: [], // Replace with actual fields if available
            gymWebsite: island.gymWebsite?.absoluteString ?? ""
        ))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Gym Details")) {
                    TextField("Gym Name", text: $islandName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    if countryService.isLoading {
                        ProgressView("Loading countries...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else if !countryService.countries.isEmpty {
                        UnifiedCountryPickerView(
                            countryService: countryService,
                            selectedCountry: $selectedCountry,
                            isPickerPresented: $isCountryPickerPresented
                        )
                        .onChange(of: selectedCountry) { newCountry in
                            if let newCountry = newCountry {
                                os_log("Selected Country: %@", log: OSLog.default, type: .info, newCountry.name.common)

                                let normalizedCountryCode = newCountry.cca2.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                os_log("Normalized Country Code 101112: %@", log: OSLog.default, type: .info, normalizedCountryCode)

                                do {
                                    requiredAddressFields = try getAddressFields(for: normalizedCountryCode)
                                } catch {
                                    os_log("Error getting address fields for country code 181920 %@: %@", log: OSLog.default, type: .error, normalizedCountryCode, error.localizedDescription)
                                    requiredAddressFields = defaultAddressFieldRequirements
                                }
                            } else {
                                requiredAddressFields = defaultAddressFieldRequirements
                            }
                        }
                    } else {
                        Text("No countries found.")
                    }
                }

                Section(header: Text("Address")) {
                    ForEach(requiredAddressFields, id: \.self) { field in
                        addressField(for: field)
                    }
                }

                Section(header: Text("Website (optional)")) {
                    TextField("Gym Website567", text: $gymWebsite)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .onChange(of: gymWebsite) { newValue in
                            if !newValue.isEmpty && !validateURL(newValue) {
                                alertMessage = "Invalid website URL"
                                showAlert = true
                            }
                        }
                }

                Section(header: Text("Entered By")) {
                    Text(profileViewModel.name)
                        .foregroundColor(.primary)
                }

                VStack {
                    Button("Save") {
                        os_log("Save button clicked", log: OSLog.default, type: .info)
                        Task { saveIsland() }
                    }
                    .disabled(!isSaveEnabled)
                }
                Spacer()
                VStack {
                    Button("Cancel") {
                        os_log("Cancel button clicked", log: OSLog.default, type: .info)
                        clearFields()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationBarTitle("Edit Gym", displayMode: .inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                updateAddressFields()
                Task {
                    await countryService.fetchCountries()
                    if let countryName = island.country,
                       let country = countryService.countries.first(where: { $0.name.common == countryName }) {
                        selectedCountry = country

                        let normalizedCountryCode = country.cca2.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        os_log("Setting initial country code: %@", log: OSLog.default, type: .info, normalizedCountryCode)

                        do {
                            requiredAddressFields = try getAddressFields(for: normalizedCountryCode)
                        } catch {
                            os_log("Error getting address fields for country code 202122 %@: %@", log: OSLog.default, type: .error, normalizedCountryCode, error.localizedDescription)
                            requiredAddressFields = defaultAddressFieldRequirements
                        }
                    }
                    parseIslandLocation(island.islandLocation ?? "")
                }
            }
            .onChange(of: islandName) { _ in validateForm() }
            .onChange(of: requiredAddressFields) { _ in validateForm() }
        }
    }

    // MARK: - Helper Methods
    private func parseIslandLocation(_ location: String) {
        let components = location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        if components.count > 0 { islandDetails.street = components[0] }
        if components.count > 1 { islandDetails.city = components[1] }
        if components.count > 2 { islandDetails.state = components[2] }
        if components.count > 3 { islandDetails.postalCode = components[3] }
        if components.count > 4 {
            let countryName = components[4]
            if let country = countryService.countries.first(where: { $0.name.common == countryName }) {
                islandDetails.selectedCountry = country
            }
        }
    }
    
    private func updateAddressFields() {
        guard let selectedCountry = islandDetails.selectedCountry else {
            requiredAddressFields = defaultAddressFieldRequirements
            return
        }
        
        let normalizedCountryCode = selectedCountry.cca2.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        os_log("Fetching address fields for normalized country code123: %@", log: OSLog.default, type: .info, normalizedCountryCode)

        do {
            requiredAddressFields = try getAddressFields(for: normalizedCountryCode)
            os_log("Updated address fields for country: %@", log: OSLog.default, type: .info, selectedCountry.name.common)
        } catch {
            os_log("Error getting address fields for country code 222324 %@: %@", log: OSLog.default, type: .error, normalizedCountryCode, error.localizedDescription)
            requiredAddressFields = defaultAddressFieldRequirements
        }
    }


    private func addressField(for field: AddressFieldType) -> some View {
        guard let keyPath = fieldValues.first(where: { $1 == field })?.0 else {
            return AnyView(EmptyView())
        }
        return AnyView(
            TextField(field.rawValue.capitalized, text: Binding(
                get: { islandDetails[keyPath: keyPath] as? String ?? "" },
                set: { newValue in
                    if let writableKeyPath = keyPath as? ReferenceWritableKeyPath<IslandDetails, String> {
                        islandDetails[keyPath: writableKeyPath] = newValue
                    }
                }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
        )
    }

    private func validateForm() {
        print("validateForm()111213 called: islandName = \(islandName)")

        isSaveEnabled = requiredAddressFields.allSatisfy { isValidField($0) } && !islandName.isEmpty
        if !isSaveEnabled {
            toastMessage = "Please fill in all required fields161718"
            showToast = true
        }
    }
    
    private func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private func saveIsland() {
        guard !islandName.isEmpty, !islandLocation.isEmpty, !lastModifiedByUserId.isEmpty else {
            showAlert = true
            alertMessage = "Please fill in all required fields192021"
            return
        }

        Task {
            do {
                islandDetails.street = islandDetails.street.trimmingCharacters(in: .whitespacesAndNewlines)
                let formattedLocation = [
                    islandDetails.street,
                    islandDetails.city,
                    islandDetails.state,
                    islandDetails.postalCode,
                    islandDetails.selectedCountry?.name.common
                ].compactMap { $0 }.joined(separator: ", ")

                island.islandLocation = formattedLocation
                island.islandName = islandName
                island.lastModifiedByUserId = lastModifiedByUserId

                try await islandViewModel.updatePirateIsland(
                    island: island,
                    islandDetails: islandDetails,
                    lastModifiedByUserId: lastModifiedByUserId
                )
                presentationMode.wrappedValue.dismiss()
            } catch {
                showAlert = true
                alertMessage = "Error saving island: \(error.localizedDescription)"
            }
        }
    }

    private func clearFields() {
        islandName = island.islandName ?? ""
        islandLocation = island.islandLocation ?? ""
        gymWebsite = island.gymWebsite?.absoluteString ?? ""
        selectedCountry = nil
        requiredAddressFields = defaultAddressFieldRequirements
    }

    private let fieldValues: [PartialKeyPath<IslandDetails>: AddressFieldType] = [
        \.street: .street,
        \.city: .city,
        \.state: .state,
        \.province: .province,
        \.postalCode: .postalCode,
        \.region: .region, // Added region case here
        \.district: .district,
        \.department: .department,
        \.governorate: .governorate,
        \.emirate: .emirate,
        \.block: .block,
        \.county: .county,
        \.neighborhood: .neighborhood,
        \.complement: .complement,
        \.apartment: .apartment,
        \.additionalInfo: .additionalInfo,
        \.multilineAddress: .multilineAddress
    ]
    
    
    private func isValidField(_ field: AddressFieldType) -> Bool {
        guard let keyPath = fieldValues.first(where: { $1 == field })?.0 else {
            return false // This should never happen unless there's an issue with the fieldValues
        }
        let value = islandDetails[keyPath: keyPath] as? String ?? ""
        return !value.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

struct EditExistingIsland_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared
        let context = persistenceController.container.viewContext

        // Create a sample PirateIsland for the preview
        let island = PirateIsland(context: context)
        island.islandName = "Sample Gym"
        island.islandLocation = "123 Main St, City, State, 12345"
        island.createdByUserId = "UserCreated"
        island.lastModifiedByUserId = "UserModified"
        island.gymWebsite = URL(string: "https://www.example.com")

        // Create the view using the proper initializers
        return EditExistingIsland(
            island: island,
            islandViewModel: PirateIslandViewModel(persistenceController: persistenceController),
            profileViewModel: ProfileViewModel(viewContext: context)
        )
        .environment(\.managedObjectContext, context)
    }
}
