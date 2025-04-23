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
    // Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    // Observed Objects
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @StateObject var countryService = CountryService.shared
    @ObservedObject var authViewModel: AuthViewModel
    
    // State Variables
    @State private var gymWebsiteURL: URL? = nil
    @State private var formState = FormState()
    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var gymWebsite = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var navigationPath = NavigationPath()
    
    @Binding var islandDetails: IslandDetails

    
    // Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                islandFormSection
                enteredBySection
                actionButtons
            }
            .navigationDestination(for: String.self) { islandMenuPath in
                IslandMenu(
                    isLoggedIn: Binding.constant(true),
                    authViewModel: authViewModel,
                    profileViewModel: profileViewModel
                )
            }
            .navigationBarTitle("Add New Gym", displayMode: .inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                loadCountries()
            }
            .overlay(toastOverlay)
            .onChange(of: islandDetails) { _ in validateForm() }
            .onChange(of: islandDetails.islandName) { _ in validateForm() }
            .onChange(of: islandDetails.requiredAddressFields) { _ in validateForm() }
        }
    }

    // MARK: - Subviews
    private var islandFormSection: some View {
        IslandFormSections(
            viewModel: islandViewModel,
            profileViewModel: profileViewModel,
            countryService: countryService,
            islandName: $islandDetails.islandName,
            street: $islandDetails.street,
            city: $islandDetails.city,
            state: $islandDetails.state,
            postalCode: $islandDetails.postalCode,
            islandDetails: $islandDetails,
            selectedCountry: $islandDetails.selectedCountry,
            gymWebsite: $gymWebsite,
            gymWebsiteURL: $gymWebsiteURL,

            // Additional address fields:
            province: $islandDetails.province,
            neighborhood: $islandDetails.neighborhood,
            complement: $islandDetails.complement,
            apartment: $islandDetails.apartment,
            region: $islandDetails.region,
            county: $islandDetails.county,
            governorate: $islandDetails.governorate,
            additionalInfo: $islandDetails.additionalInfo,

            // More address fields:
            department: $islandDetails.department,
            parish: $islandDetails.parish,
            district: $islandDetails.district,
            entity: $islandDetails.entity,
            municipality: $islandDetails.municipality,
            division: $islandDetails.division,
            emirate: $islandDetails.emirate,
            zone: $islandDetails.zone,
            block: $islandDetails.block,
            island: $islandDetails.island,

            // Validation and alert:
            isIslandNameValid: $islandDetails.isIslandNameValid,
            islandNameErrorMessage: $islandDetails.islandNameErrorMessage,
            isFormValid: $isSaveEnabled,
            showAlert: $showAlert,
            alertMessage: $alertMessage,

            // FormState argument should come last:
            formState: $formState
        )
    }




    private var enteredBySection: some View {
        Section(header: Text("Entered By")) {
            Text(profileViewModel.name)
                .foregroundColor(.primary)
        }
    }

    private var actionButtons: some View {
        VStack {
            saveButton
            cancelButton
        }
    }

    private var saveButton: some View {
        Button("Save") {
            os_log("Save button clicked", log: OSLog.default, type: .info)
            
            // Ensure getCurrentUser correctly fetches the user
            Task {
                // Now we await the current user
                if let currentUser = await authViewModel.getCurrentUser() {
                    if currentUser.name.isEmpty {
                        self.alertMessage = "Could not find your profile info. Please log in again."
                        self.showAlert = true
                        return
                    }
                    
                    // Proceed with saving the island once the user is verified
                    await saveIsland(currentUser: currentUser) {
                        // Once the save operation completes, navigate
                        navigationPath.append("IslandMenu")
                    }
                } else {
                    self.alertMessage = "You must be logged in to save a new gym."
                    self.showAlert = true
                }
            }
        }
        .disabled(!isSaveEnabled)
    }



    private var cancelButton: some View {
        Button("Cancel") {
            os_log("Cancel button clicked", log: OSLog.default, type: .info)
            clearFields()
            presentationMode.wrappedValue.dismiss()
        }
    }

    // MARK: - Helper Methods

    private func loadCountries() {
        Task {
            // Load countries on appear
            await countryService.fetchCountries()
            if let usa = countryService.countries.first(where: { $0.cca2 == "US" }) {
                islandDetails.selectedCountry = usa
            }
            os_log("Countries loaded successfully", log: OSLog.default, type: .info)
        }
    }


    // MARK: - Helper Methods



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

    private func validateForm() {
        print("Validating form...123")
        
        // 🔍 Debug tip: Print the current state of islandDetails
        print("Current islandDetails: \(islandDetails)")

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

        let finalIsValid = !islandDetails.islandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        print("Final validation result: \(finalIsValid)")
        
        isSaveEnabled = isSaveEnabled && finalIsValid // Update isSaveEnabled
    }


    private func isValidField(_ field: AddressFieldType) -> Bool {
        guard let keyPath = fieldValues.first(where: { $1 == field })?.0 else {
            return false
        }
        let value = islandDetails[keyPath: keyPath] as? String ?? ""
        return !value.isEmpty
    }


    private func saveIsland(currentUser: User, onSave: @escaping () -> Void) async {
        guard isSaveEnabled else {
            toastMessage = "Please fill in all required fields"
            showToast = true
            return
        }

        do {
            let newIsland = try await islandViewModel.createPirateIsland(
                islandDetails: islandDetails,
                createdByUserId: currentUser.userName,
                gymWebsite: gymWebsite,
                country: islandDetails.selectedCountry?.cca2 ?? "",
                selectedCountry: islandDetails.selectedCountry!,
                createdByUser: currentUser
            )

            toastMessage = "Island saved successfully: \(newIsland.islandName ?? "Unknown Name")"
            clearFields()
            onSave()

        } catch let error as PirateIslandError {
            print("PirateIslandError: \(error)")
            if case .geocodingError(let underlyingError) = error {
                print("Underlying geocoding error: \(underlyingError)")
            }
            toastMessage = "Error saving island: \(error.localizedDescription)"
            showToast = true

        } catch {
            print("Unexpected error: \(error)")
            toastMessage = "An unexpected error occurred: \(error.localizedDescription)"
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
        
        // Create a mock IslandDetails for the preview
        var mockIslandDetails = IslandDetails()
        mockIslandDetails.islandName = "Test Island"
        mockIslandDetails.street = "123 Paradise Ave"
        mockIslandDetails.city = "Wonderland"
        mockIslandDetails.state = "Fantasy"
        mockIslandDetails.postalCode = "12345"
        
        // Use the Country model from your existing CountryService
        let mockCountry = Country(name: Country.Name(common: "USA"), cca2: "US", flag: "🇺🇸")
        mockIslandDetails.selectedCountry = mockCountry

        // Create a mock AuthViewModel for the preview
        let mockAuthViewModel = AuthViewModel.shared
        
        // Create a Binding for islandDetails
        let islandDetailsBinding = Binding(
            get: { mockIslandDetails },
            set: { mockIslandDetails = $0 }
        )
        
        return AddNewIsland(islandViewModel: islandViewModel, profileViewModel: profileViewModel, authViewModel: mockAuthViewModel, islandDetails: islandDetailsBinding)
            .environment(\.managedObjectContext, persistenceController.viewContext)
    }
}
