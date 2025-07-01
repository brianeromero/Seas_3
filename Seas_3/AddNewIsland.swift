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

public struct AddNewIsland: View {
    // Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss // ✅ Correct way to use @Environment(\.dismiss)

    // ✅ Change to @EnvironmentObject for shared view models
    @EnvironmentObject var islandViewModel: PirateIslandViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @StateObject var countryService = CountryService.shared // This can remain @StateObject if it's unique to this view's lifecycle
    
    // State Variables
    @State private var gymWebsiteURL: URL? = nil
    @State private var formState = FormState()
    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var gymWebsite = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @Binding var navigationPath: NavigationPath

    @Binding var islandDetails: IslandDetails
    @State private var isSuccessAlert = false

    // Body
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                islandFormSection
                enteredBySection
                actionButtons
            }
            .navigationDestination(for: String.self) { islandMenuPath in
                IslandMenu2(
                    profileViewModel: profileViewModel, // `profileViewModel` is now @EnvironmentObject
                    navigationPath: $navigationPath
                )
            }
            .navigationBarTitle("Add New Gym", displayMode: .inline)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(isSuccessAlert ? "Success" : "Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if isSuccessAlert {
                            navigationPath = NavigationPath()
                        }
                    }

                )
            }
            .onAppear {
                loadCountries()
            }
            .onChange(of: islandDetails) { _ in validateForm() }
            .onChange(of: islandDetails.islandName) { _ in validateForm() }
            .onChange(of: islandDetails.requiredAddressFields) { _ in validateForm() }
        }
    }

    // MARK: - Subviews
    private var islandFormSection: some View {
        IslandFormSections(
            viewModel: islandViewModel, // Now @EnvironmentObject
            profileViewModel: profileViewModel, // Now @EnvironmentObject
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
                if let currentUser = await authViewModel.getCurrentUser() { // authViewModel is now @EnvironmentObject
                    if currentUser.name.isEmpty {
                        self.alertMessage = "Could not find your profile info. Please log in again."
                        self.showAlert = true
                        return
                    }
                    
                    // Proceed with saving the island once the user is verified
                    await saveIsland(currentUser: currentUser) {
                        // Once the save operation completes, navigate
                        navigationPath.append("IslandMenu2")
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
            dismiss()
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

        guard let selectedCountry = islandDetails.selectedCountry else {
            toastMessage = "Please select a country."
            showToast = true
            return
        }

        do {
            let newIsland = try await islandViewModel.createPirateIsland( // islandViewModel is now @EnvironmentObject
                islandDetails: islandDetails,
                createdByUserId: currentUser.userName,
                gymWebsite: gymWebsite,
                country: selectedCountry.cca2,
                selectedCountry: selectedCountry,
                createdByUser: currentUser
            )

            toastMessage = "Island saved successfully: \(newIsland.islandName ?? "Unknown Name")"
            alertMessage = "Gym Added Successfully!"
            isSuccessAlert = true
            showAlert = true
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
        gymWebsite = ""
        islandDetails.gymWebsite = ""
        gymWebsiteURL = nil
    }
}
