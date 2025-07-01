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

public struct EditExistingIsland: View {
    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    // MARK: - Observed Objects
    @ObservedObject var island: PirateIsland // The Core Data object
    @EnvironmentObject var pirateIslandViewModel: PirateIslandViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    @StateObject var islandDetails = IslandDetails() // Holds form data
    @StateObject private var countryService = CountryService()
    @State private var isCountryPickerPresented = false

    // MARK: - State Variables
    // These are now minimal, as form data is managed by islandDetails
    @State private var isSaveEnabled: Bool = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    // MARK: - Initialization
    // Initial values for islandDetails are set in .onAppear
    init(island: PirateIsland) {
        _island = ObservedObject(wrappedValue: island)
    }

    // MARK: - Body
    public var body: some View {
        Form {
            Section(header: Text("Gym Details")) {
                TextField("Gym Name", text: $islandDetails.islandName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: islandDetails.islandName) { _, _ in validateForm() }

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
                    .onChange(of: islandDetails.selectedCountry) { _, _ in
                        // Country selection now only triggers form validation
                        validateForm()
                    }
                } else {
                    Text("No countries found.")
                }
            }

            Section(header: Text("Address")) {
                // Changed from TextField to TextEditor for multi-line input
                TextEditor(text: $islandDetails.multilineAddress)
                    .frame(minHeight: 100) // Give it a reasonable minimum height
                    .border(Color.gray.opacity(0.5), width: 1) // Add a border for visual clarity
                    .cornerRadius(5) // Rounded corners for consistency
                    .onChange(of: islandDetails.multilineAddress) { _, _ in validateForm() }
            }

            Section(header: Text("Website (optional)")) {
                TextField("Gym Website", text: $islandDetails.gymWebsite)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .onChange(of: islandDetails.gymWebsite) { _, newValue in
                        if !newValue.isEmpty && !validateURL(newValue) {
                            alertMessage = "Invalid website URL"
                            showAlert = true
                        }
                        validateForm()
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
                    dismiss()
                }
            }
        }
        .navigationBarTitle("Edit Gym", displayMode: .inline)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            os_log("EditExistingIsland Appeared", log: OSLog.default, type: .info)
            // Initialize islandDetails from the Core Data island object
            islandDetails.islandName = island.islandName ?? ""
            islandDetails.multilineAddress = island.islandLocation ?? ""
            islandDetails.latitude = island.latitude
            islandDetails.longitude = island.longitude
            islandDetails.gymWebsite = island.gymWebsite?.absoluteString ?? ""

            // Set the selected country in islandDetails if available from Core Data
            if let countryCode = island.country,
               let country = countryService.countries.first(where: { $0.cca2 == countryCode }) {
                islandDetails.selectedCountry = country
            } else {
                islandDetails.selectedCountry = nil
            }

            Task {
                await countryService.fetchCountries()
                validateForm() // Validate form after countries are fetched and initial data is set
            }
        }
    }

    // MARK: - Helper Methods

    // Simplified validation logic
    private func validateForm() {
        print("validateForm() called: islandName = \(islandDetails.islandName)")

        let isIslandNameNonEmpty = !islandDetails.islandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isLocationNonEmpty = !islandDetails.multilineAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isCountrySelected = islandDetails.selectedCountry != nil
        let isWebsiteValid = islandDetails.gymWebsite.isEmpty || validateURL(islandDetails.gymWebsite)

        isSaveEnabled = isIslandNameNonEmpty && isLocationNonEmpty && isCountrySelected && isWebsiteValid

        if !isSaveEnabled {
            toastMessage = "Please fill in all required fields (Gym Name, Address, Country) and ensure website is valid (if entered)."
            showToast = true
        }
        print("isSaveEnabled: \(isSaveEnabled)")
    }

    // Corrected URL validation logic
    private func validateURL(_ urlString: String) -> Bool {
        // Attempt to create a URL from the string as-is and check if it can be opened
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            return true
        }
        // If that fails, try prepending "https://" and check again
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if let urlWithHTTPS = URL(string: "https://" + urlString), UIApplication.shared.canOpenURL(urlWithHTTPS) {
                return true
            }
        }
        // If neither attempt works, or the string is empty/malformed, it's invalid
        return false
    }

    // Simplified save logic
    private func saveIsland() {
        guard let currentUserId = authViewModel.currentUserID else {
            showAlert = true
            alertMessage = "User not logged in. Please log in to save."
            return
        }

        Task {
            do {
                island.islandName = islandDetails.islandName
                // Directly assign the multilineAddress to islandLocation Core Data property
                island.islandLocation = islandDetails.multilineAddress

                island.latitude = islandDetails.latitude ?? 0.0
                island.longitude = islandDetails.longitude ?? 0.0

                // Assign the country code from the selected Country object
                island.country = islandDetails.selectedCountry?.cca2

                // Handle gymWebsite URL conversion
                if let url = URL(string: islandDetails.gymWebsite.hasPrefix("http") ? islandDetails.gymWebsite : "https://\(islandDetails.gymWebsite)") {
                    island.gymWebsite = url
                } else {
                    island.gymWebsite = nil
                }

                island.lastModifiedByUserId = currentUserId
                island.lastModifiedTimestamp = Date()

                try await pirateIslandViewModel.updatePirateIsland(
                    island: island,
                    islandDetails: islandDetails,
                    lastModifiedByUserId: currentUserId
                )

                showAlert = true
                alertMessage = "Gym Updated Successfully!"
                dismiss()
            } catch {
                showAlert = true
                alertMessage = "Error saving gym: \(error.localizedDescription)"
                os_log("Error saving gym: %{public}@", type: .error, error.localizedDescription)
            }
        }
    }

    // Simplified clear fields logic
    private func clearFields() {
        islandDetails.islandName = ""
        islandDetails.multilineAddress = ""
        islandDetails.selectedCountry = nil
        islandDetails.gymWebsite = ""
        islandDetails.latitude = 0.0
        islandDetails.longitude = 0.0
        validateForm()
    }
}
