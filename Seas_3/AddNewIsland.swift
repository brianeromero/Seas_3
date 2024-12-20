//
//  AddNewIsland.swift
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

struct AddNewIsland: View {
    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    // MARK: - Observed Objects
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @StateObject var islandDetails = IslandDetails()
    @ObservedObject var countryService = CountryService.shared
    @State private var isCountryPickerPresented = false
    
    // MARK: - State Variables
    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var showIslandMenu = false
    @State private var navigationPath: [String] = []

    @State private var alertMessage = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isLoadingCountries = true
    @State private var gymWebsite = ""
    
    // MARK: - Initialization
    init(viewModel: PirateIslandViewModel, profileViewModel: ProfileViewModel) {
        self.islandViewModel = viewModel
        self.profileViewModel = profileViewModel
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                Section(header: Text("Gym Details")) {
                    TextField("Gym Name", text: $islandDetails.islandName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if countryService.isLoading {
                        ProgressView("Loading countries...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else if !countryService.countries.isEmpty {
                        UnifiedCountryPickerView(
                            countryService: countryService,
                            selectedCountry: $islandDetails.selectedCountry,
                            isPickerPresented: $isCountryPickerPresented
                        )
                        .onChange(of: islandDetails.selectedCountry) { newCountry in
                            if let newCountry = newCountry {
                                islandDetails.requiredAddressFields = getAddressFields(for: newCountry.cca2)
                            } else {
                                islandDetails.requiredAddressFields = defaultAddressFieldRequirements
                            }
                        }
                    } else {
                        Text("No countries found.")
                    }
                }
                
                Section(header: Text("Address")) {
                    ForEach(islandDetails.requiredAddressFields, id: \.self) { field in
                        addressField(for: field)
                    }
                }
                
                Section(header: Text("Website (optional)")) {
                    TextField("Gym Website", text: $gymWebsite)
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
                        Task {
                            await saveIsland {
                                navigationPath.append("IslandMenu")
                            }
                        }
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
            .navigationDestination(for: String.self) { islandMenuPath in
                IslandMenu(isLoggedIn: Binding.constant(true))
            }
            .navigationBarTitle("Add New Gym", displayMode: .inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                islandDetails.onValidationChange = { isValid in
                    isSaveEnabled = isValid
                }
                
                Task {
                    await countryService.fetchCountries()
                    if let usa = countryService.countries.first(where: { $0.cca2 == "US" }) {
                        islandDetails.selectedCountry = usa
                    }
                    updateAddressFields()
                    os_log("Countries loaded successfully", log: OSLog.default, type: .info)
                }
            }
            
            .overlay(toastOverlay)
            .onChange(of: islandDetails) { _ in validateForm() }
            .onChange(of: islandDetails.islandName) { _ in validateForm() }
            .onChange(of: islandDetails.requiredAddressFields) { _ in validateForm() }
        }
    }


    // MARK: - Helper Methods
    private func updateAddressFields() {
        guard let selectedCountry = islandDetails.selectedCountry else {
            islandDetails.requiredAddressFields = defaultAddressFieldRequirements
            return
        }
        islandDetails.requiredAddressFields = getAddressFields(for: selectedCountry.cca2)
        print("Country: \(selectedCountry.name.common), Custom Fields: \(islandDetails.requiredAddressFields.map { $0.rawValue })")
        os_log("Updated address fields for country: %@", log: OSLog.default, type: .info, selectedCountry.name.common)
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

    private func setValue(value: String, forKeyPath keyPath: ReferenceWritableKeyPath<IslandDetails, String>) {
        islandDetails[keyPath: keyPath] = value
    }
    
    private func validateForm() {
        print("Validating form...")
        let requiredFields = islandDetails.requiredAddressFields
        print("Required fields: \(requiredFields.map { $0.rawValue })")
        isSaveEnabled = true // Assume the form is valid initially
        for field in requiredFields {
            print("Checking field \(field.rawValue): \(isValidField(field))")
            if !isValidField(field) {
                toastMessage = "Please fill in \(field.rawValue)"
                showToast = true
                isSaveEnabled = false // Update isSaveEnabled to false
                return
            }
        }
        let finalIsValid = !islandDetails.islandName.isEmpty
        print("Final validation result: \(finalIsValid)")
        isSaveEnabled = isSaveEnabled && finalIsValid // Update isSaveEnabled
    }

    
    private func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            return false
        }
        return true
    }


    private func isValidField(_ field: AddressFieldType) -> Bool {
        guard let keyPath = fieldValues.first(where: { $1 == field })?.0 else {
            return false
        }
        let value = islandDetails[keyPath: keyPath] as? String ?? ""
        return !value.isEmpty
    }


    private func saveIsland(onSave: @escaping () -> Void) async {
        if isSaveEnabled {
            do {
                let newIsland = try await islandViewModel.createPirateIsland(islandDetails: islandDetails, createdByUserId: profileViewModel.name, gymWebsite: gymWebsite)

                // Store the country and gym website URL in the new island
                newIsland.country = islandDetails.selectedCountry?.name.common
                
                if !gymWebsite.isEmpty {
                    if let url = URL(string: gymWebsite) {
                        newIsland.gymWebsite = url
                    } else {
                        // Handle invalid URL
                        toastMessage = "Invalid gym website URL"
                        showToast = true
                        return
                    }
                }
                
                try viewContext.save()
                
                toastMessage = "Island saved successfully: \(newIsland.islandName ?? "Unknown Name")"
                clearFields()
                
                // Call the onSave callback
                onSave()
            } catch {
                if let error = error as? PirateIslandError {
                    toastMessage = "Error saving island: \(error.localizedDescription)"
                    showToast = true
                } else {
                    toastMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    showToast = true
                }
            }
        } else {
            toastMessage = "Please fill in all required fields"
            showToast = true
        }
    }

    private func clearFields() {
        islandDetails.islandName = ""
        islandDetails.street = ""
        islandDetails.city = ""
        islandDetails.state = ""
        islandDetails.postalCode = ""
        islandDetails.selectedCountry = nil
        islandDetails.neighborhood = ""
        islandDetails.complement = ""
        islandDetails.block = ""
        islandDetails.apartment = ""
        islandDetails.region = ""
        islandDetails.county = ""
        islandDetails.governorate = ""
        islandDetails.province = ""
        islandDetails.additionalInfo = ""
        gymWebsite = "" // Clear gymWebsite when cancelling
    }


    private var toastOverlay: some View {
        Group {
            if showToast {
                ToastView(showToast: $showToast, message: toastMessage)
                    .transition(.move(edge: .bottom))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showToast = false
                        }
                    }
            }
        }
    }
}

// MARK: - Preview
struct AddNewIsland_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let profileViewModel = ProfileViewModel(viewContext: persistenceController.viewContext, authViewModel: AuthViewModel.shared)
        profileViewModel.name = "Brian Romero"

        let islandViewModel = PirateIslandViewModel(persistenceController: persistenceController)

        return AddNewIsland(viewModel: islandViewModel, profileViewModel: profileViewModel)
    }
}
