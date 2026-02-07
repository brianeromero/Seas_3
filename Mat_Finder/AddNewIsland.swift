//
//  AddNewIsland.swift
//  Mat_Finder
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
    
    @ObservedObject var countryService = CountryService.shared

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
    
    @State private var showValidationMessage = false
    @State private var missingFields: [String] = []


    // Body
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                islandFormSection
                
                // ✅ Missing fields message goes here
                if showValidationMessage && !missingFields.isEmpty {
                    Text("Required fields are missing: \(missingFields.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.red)
                        .onAppear {
                            print("❌ Missing fields: \(missingFields)")
                        }
                }
                
                
                enteredBySection
                actionButtons
            }
            .overlay(
                VStack {
                    Spacer()
                    if showToast {
                        Text(toastMessage)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation { showToast = false }
                                }
                            }
                    }
                }
                .padding()
                .animation(.easeInOut, value: showToast)
            )
        }
        .navigationDestination(for: String.self) { islandMenuPath in
            IslandMenu2(
                navigationPath: $navigationPath,
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                Text("Add New Gym")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Fill in all required fields below")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
        }

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
            // Fetch countries
            Task { await countryService.fetchCountries() }

            // Load profile
            Task {
                if let userID = await authViewModel.getCurrentUser()?.userID {
                    await profileViewModel.loadProfile(for: userID)
                }
                validateForm()
            }
        }


        .onChange(of: countryService.countries) { oldValue, newValue in
            if let usa = newValue.first(where: { $0.cca2 == "US" }) {
                islandDetails.selectedCountry = usa
            }
        }
        .onChange(of: islandDetails) { _, _ in validateForm() }
        .onChange(of: islandDetails.islandName) { _, _ in validateForm() }
        .onChange(of: islandDetails.requiredAddressFields) { _, _ in validateForm() }
    }


    // MARK: - Subviews
    private var islandFormSection: some View {
        IslandFormSections(
            viewModel: islandViewModel,
            profileViewModel: profileViewModel,
            islandName: $islandDetails.islandName,
            street: $islandDetails.street,
            city: $islandDetails.city,
            state: $islandDetails.state,
            postalCode: $islandDetails.postalCode,
            islandDetails: $islandDetails,
            selectedCountry: $islandDetails.selectedCountry,
            gymWebsite: $gymWebsite,
            gymWebsiteURL: $gymWebsiteURL,

            // Additional address fields
            province: $islandDetails.province,
            neighborhood: $islandDetails.neighborhood,
            complement: $islandDetails.complement,
            apartment: $islandDetails.apartment,
            region: $islandDetails.region,
            county: $islandDetails.county,
            governorate: $islandDetails.governorate,
            additionalInfo: $islandDetails.additionalInfo,
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

            // Validation bindings
            isSaveEnabled: $isSaveEnabled,
            showValidationMessage: $showValidationMessage,
            missingFields: $missingFields
        )

    }


    private var enteredBySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Entered By")
                .font(.headline)
                .foregroundColor(.primary)
            
            if profileViewModel.isProfileLoaded {
                Text(profileViewModel.userName.isEmpty ? "Unknown" : profileViewModel.userName)
                    .font(.body)
                    .foregroundColor(.primary)
            } else {
                ProgressView()
                    .scaleEffect(0.75, anchor: .leading)
            }
        }
    }



    private var actionButtons: some View {
        VStack(spacing: 14) {
            saveButton
            cancelButton
        }
        .padding(.top, 20)
    }


    private var saveButton: some View {
        Button(action: {
            os_log("Save button clicked", log: OSLog.default, type: .info)

            Task {
                let requiredFields = islandDetails.requiredAddressFields

                let missing = requiredFields
                    .filter { !isValidField($0) }
                    .map { $0.rawValue }

                // 🔴 trigger inline validation
                self.missingFields = missing
                self.showValidationMessage = true

                // ✅ ADD THIS RIGHT HERE
                let isIslandNameEmpty =
                    islandDetails.islandName
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty

                if !missing.isEmpty || isIslandNameEmpty {
                    toastMessage = "Please fill in all required fields"
                    showToast = true
                    return
                }

                guard let currentUser = await authViewModel.getCurrentUser() else {
                    alertMessage = "You must be logged in to add a new gym location."
                    showAlert = true
                    return
                }

                await saveIsland(currentUser: currentUser) {
                    navigationPath.append("IslandMenu2")
                }
            }
        }) {
            Text("Save")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
    }



    private var cancelButton: some View {
        Button(action: {
            os_log("Cancel button clicked", log: OSLog.default, type: .info)
            clearFields()
            dismiss()
        }) {
            Text("Cancel")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .foregroundColor(.red)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
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
        
        // 🔍 Debug: Print current islandDetails
        print("Current islandDetails: \(islandDetails)")

        let requiredFields = islandDetails.requiredAddressFields
        print("Required fields: \(requiredFields.map { $0.rawValue })")

        // Check if islandName is empty
        let islandNameEmpty = islandDetails.islandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        print("Island Name empty? \(islandNameEmpty) -> '\(islandDetails.islandName)'")

        // Check each required address field
        for field in requiredFields {
            let valid = isValidField(field)
            print("Field '\(field.rawValue)' valid? \(valid) -> '\(valueForField(field))'")
        }

        // Enable Save button
        isSaveEnabled = true

        // Show toast if anything missing
        if islandNameEmpty || requiredFields.contains(where: { !isValidField($0) }) {
            toastMessage = "Some required fields are missing"
            print("⚠️ Some required fields are missing! Current state logged above.")
        } else {
            toastMessage = ""
        }
    }
    
    
    private func valueForField(_ field: AddressFieldType) -> String {
        if let keyPath = fieldValues.first(where: { $1 == field })?.0 {
            return islandDetails[keyPath: keyPath] as? String ?? ""
        }
        return ""
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

extension ProfileViewModel {
    var isProfileLoaded: Bool {
        switch loadState {
        case .loaded:
            return true
        default:
            return false
        }
    }
}
