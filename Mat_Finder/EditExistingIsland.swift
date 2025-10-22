//  EditExistingIsland.swift
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
import OSLog // Ensure OSLog is imported for os_log


public struct EditExistingIsland: View {
    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    // MARK: - Observed Objects
    @ObservedObject var island: PirateIsland // The Core Data object
    @EnvironmentObject var pirateIslandViewModel: PirateIslandViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel // Keep this

    @StateObject var islandDetails = IslandDetails()
    @StateObject private var countryService = CountryService()
    @State private var isCountryPickerPresented = false

    // MARK: - State Variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Binding var showSuccessToast: Bool
    @Binding var successToastMessage: String
    @Binding var successToastType: ToastView.ToastType // <<< NEW: Add this binding


    @State private var originalIslandName: String = ""
    @State private var originalMultilineAddress: String = ""
    @State private var originalSelectedCountryCCA2: String? = nil
    @State private var originalGymWebsite: String = ""

    @State private var createdByName: String = "Loading..."
    @State private var lastModifiedByName: String = "Loading..."
    @State private var displayedCountryName: String = "" // State to hold the displayed country name

    // MARK: - Initialization (Update init to include new bindings)
    init(island: PirateIsland, showSuccessToast: Binding<Bool>, successToastMessage: Binding<String>, successToastType: Binding<ToastView.ToastType>) { // <<< NEW: Update init
        _island = ObservedObject(wrappedValue: island)
        _showSuccessToast = showSuccessToast
        _successToastMessage = successToastMessage
        _successToastType = successToastType // <<< NEW: Initialize the new binding
    }

    // MARK: - Body
    public var body: some View {
        Form {
            Section(header: Text("Gym Details")) {
                TextField("Gym Name", text: $islandDetails.islandName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Display the Country
            Section(header: Text("Country")) {
                Text(displayedCountryName)
                    .foregroundColor(.primary)
            }

            Section(header: Text("Address")) {
                TextEditor(text: $islandDetails.multilineAddress)
                    .frame(minHeight: 100)
                    .border(Color.gray.opacity(0.5), width: 1)
                    .cornerRadius(5)
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
                    }
            }

            Section(header: Text("Entered By")) {
                Text(createdByName)
                    .foregroundColor(.primary)
            }

            Section(header: Text("Last Modified By")) {
                Text(lastModifiedByName)
                    .foregroundColor(.primary)
            }

            VStack {
                Button("Save") {
                    os_log("Save button clicked", log: OSLog.default, type: .info)
                    Task { await saveIsland() }
                }
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
            islandDetails.islandID = island.islandID

            // Initialize the displayedCountryName directly from the island object
            // FIX for empty country: Check if string is empty after trimming
            displayedCountryName = island.country?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? island.country! : "Unknown"

            // --- ADDED LOGGING FOR INITIAL DISPLAY VALUES ---
            os_log("Initial Display Values:", log: OSLog.default, type: .info)
            os_log("  islandDetails.islandName: %{public}@", log: OSLog.default, type: .info, islandDetails.islandName)
            os_log("  islandDetails.multilineAddress: %{public}@", log: OSLog.default, type: .info, islandDetails.multilineAddress)
            os_log("  islandDetails.gymWebsite: %{public}@", log: OSLog.default, type: .info, islandDetails.gymWebsite)
            os_log("  island.country (raw from Core Data): %{public}@", log: OSLog.default, type: .info, island.country ?? "nil")
            os_log("  displayedCountryName (after processing): %{public}@", log: OSLog.default, type: .info, displayedCountryName)
            os_log("  island.createdByUserId (raw from Core Data): %{public}@", log: OSLog.default, type: .info, island.createdByUserId ?? "nil")
            // --- END ADDED LOGGING ---

            Task {
                await countryService.fetchCountries()

                if let countryCode = island.country,
                    let country = countryService.countries.first(where: { $0.cca2 == countryCode }) {
                    islandDetails.selectedCountry = country
                } else {
                    islandDetails.selectedCountry = nil
                }

                // Store original values for change detection
                originalIslandName = islandDetails.islandName
                originalMultilineAddress = islandDetails.multilineAddress
                originalSelectedCountryCCA2 = islandDetails.selectedCountry?.cca2
                originalGymWebsite = islandDetails.gymWebsite

                // --- MODIFIED LOGIC FOR "Entered By" ---
                if let createdByValue = island.createdByUserId {
                    os_log("Attempting to resolve 'Entered By' for value: %{public}@", log: OSLog.default, type: .info, createdByValue)

                    var resolvedName: String?

                    // 1. Try to fetch by User ID (UID) first
                    // This assumes createdByValue *might* be a UID.
                    os_log("Trying to fetch by User ID (UID): %{public}@", log: OSLog.default, type: .info, createdByValue)
                    resolvedName = await authViewModel.fetchUserName(forUserID: createdByValue)

                    // 2. If fetching by User ID failed, try to fetch by User Name
                    // This assumes createdByValue *might* be a username.
                    if resolvedName == nil {
                        os_log("Fetching by User ID failed for %{public}%. Trying to fetch by User Name...", log: OSLog.default, type: .info, createdByValue)
                        resolvedName = await authViewModel.fetchUserName(forUserName: createdByValue)
                    }

                    await MainActor.run {
                        self.createdByName = resolvedName ?? "Unknown Creator"
                        os_log("Created By Name set to: %{public}@", log: OSLog.default, type: .info, self.createdByName)
                    }
                } else {
                    await MainActor.run {
                        self.createdByName = "N/A (No creator ID/UserName)"
                        os_log("Created By User ID is nil, setting name to N/A", log: OSLog.default, type: .info)
                    }
                }
                // --- END MODIFIED LOGIC ---

                if let currentUser = authViewModel.currentUser {
                    await MainActor.run {
                        self.lastModifiedByName = currentUser.userName
                        os_log("Last Modified By Name set to current user's username: %{public}@", log: OSLog.default, type: .info, self.lastModifiedByName)
                    }
                } else {
                    await MainActor.run {
                        self.lastModifiedByName = "Not Logged In"
                        os_log("Current user is nil, setting Last Modified By to 'Not Logged In'", log: OSLog.default, type: .info)
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func hasChanges() -> Bool {
        let currentIslandName = islandDetails.islandName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentMultilineAddress = islandDetails.multilineAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentGymWebsite = islandDetails.gymWebsite.trimmingCharacters(in: .whitespacesAndNewlines)

        let originalName = originalIslandName.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalAddress = originalMultilineAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalWebsite = originalGymWebsite.trimmingCharacters(in: .whitespacesAndNewlines)

        if currentIslandName != originalName {
            os_log("Change detected: Island Name", log: OSLog.default, type: .info)
            return true
        }
        if currentMultilineAddress != originalAddress {
            os_log("Change detected: Address", log: OSLog.default, type: .info)
            return true
        }
        // If you removed the country picker, remove this block
        if islandDetails.selectedCountry?.cca2 != originalSelectedCountryCCA2 {
            os_log("Change detected: Country", log: OSLog.default, type: .info)
            return true
        }
        if currentGymWebsite != originalWebsite {
            os_log("Change detected: Website", log: OSLog.default, type: .info)
            return true
        }

        return false
    }

    private func validateURL(_ urlString: String) -> Bool {
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            return true
        }
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if let urlWithHTTPS = URL(string: "https://" + urlString), UIApplication.shared.canOpenURL(urlWithHTTPS) {
                return true
            }
        }
        return false
    }

    private func saveIsland() async {
        os_log("saveIsland() called.", log: OSLog.default, type: .info)

        guard hasChanges() else {
            await MainActor.run {
                showAlert = true
                alertMessage = "No changes detected. Please make a change to one of the fields to save."
            }
            os_log("No changes detected.", log: OSLog.default, type: .info)
            return
        }

        let isIslandNameNonEmpty = !islandDetails.islandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isLocationNonEmpty = !islandDetails.multilineAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard isIslandNameNonEmpty && isLocationNonEmpty else {
            await MainActor.run {
                showAlert = true
                alertMessage = "Please fill in all required fields (Gym Name, Address)."
                // <<< NEW: Also set toast if you want it for validation errors
                self.successToastMessage = "Please fill in all required fields (Gym Name, Address)."
                self.successToastType = .error
                self.showSuccessToast = true
                // <<< END NEW
            }
            os_log("Validation failed: required fields missing.", log: OSLog.default, type: .error)
            return
        }

        if !islandDetails.gymWebsite.isEmpty && !validateURL(islandDetails.gymWebsite) {
            await MainActor.run {
                showAlert = true
                alertMessage = "Invalid website URL. Please correct it or leave it empty."
                // <<< NEW: Also set toast if you want it for validation errors
                self.successToastMessage = "Invalid website URL. Please correct it or leave it empty."
                self.successToastType = .error
                self.showSuccessToast = true
                // <<< END NEW
            }
            os_log("Validation failed: invalid website URL.", log: OSLog.default, type: .error)
            return
        }

        guard let currentUserId = authViewModel.currentUser?.userID else {
            await MainActor.run {
                showAlert = true
                alertMessage = "User not logged in. Please log in to save."
                // <<< NEW: Also set toast if you want it for validation errors
                self.successToastMessage = "User not logged in. Please log in to save."
                self.successToastType = .error
                self.showSuccessToast = true
                // <<< END NEW
            }
            os_log("Current user ID is nil.", log: OSLog.default, type: .error)
            return
        }
        os_log("Current User ID: %{public}@", log: OSLog.default, type: .info, currentUserId)

        // Capture values needed for updates outside the Core Data perform block
        let newIslandName = islandDetails.islandName
        let newIslandLocation = islandDetails.multilineAddress
        let newLatitude = islandDetails.latitude ?? 0.0
        let newLongitude = islandDetails.longitude ?? 0.0
        let newCountryCCA2 = islandDetails.selectedCountry?.cca2
        let newGymWebsite = islandDetails.gymWebsite

        do {
            // 1️⃣ Update Core Data model on its designated queue (main queue for viewContext)
            try await viewContext.perform {
                island.islandName = newIslandName
                island.islandLocation = newIslandLocation
                island.latitude = newLatitude
                island.longitude = newLongitude
                island.country = newCountryCCA2
                island.lastModifiedByUserId = currentUserId // Update last modified user
                island.lastModifiedTimestamp = Date() // Update timestamp

                if !newGymWebsite.isEmpty {
                    let urlString = newGymWebsite.hasPrefix("http")
                        ? newGymWebsite
                        : "https://\(newGymWebsite)"
                    // Safely create URL
                    if let url = URL(string: urlString) {
                        island.gymWebsite = url
                    } else {
                        os_log("Warning: Could not create URL from string: %{public}@", log: OSLog.default, type: .error, urlString)
                        island.gymWebsite = nil // Set to nil if URL creation fails
                    }
                } else {
                    island.gymWebsite = nil // Clear the website if empty
                }

                // Save the context after modifications
                try self.viewContext.save()
            }

            // 2️⃣ Prepare data for Firestore update
            if let islandID = island.islandID?.uuidString {
                var dataToUpdate: [String: Any] = [
                    "islandName": newIslandName,
                    "islandLocation": newIslandLocation,
                    "latitude": newLatitude,
                    "longitude": newLongitude,
                    "country": newCountryCCA2 ?? NSNull(), // Use NSNull for nil if Firestore expects it
                    "lastModifiedByUserId": currentUserId,
                    "lastModifiedTimestamp": Timestamp(date: Date()) // Firestore Timestamp
                ]

                if !newGymWebsite.isEmpty {
                    let urlString = newGymWebsite.hasPrefix("http")
                        ? newGymWebsite
                        : "https://\(newGymWebsite)"
                    dataToUpdate["gymWebsite"] = urlString
                } else {
                    dataToUpdate["gymWebsite"] = NSNull() // Clear website in Firestore
                }

                // 3️⃣ Call ViewModel to update Firestore
                try await pirateIslandViewModel.updatePirateIsland(id: islandID, data: dataToUpdate)
            }

            // 4️⃣ Update UI on MainActor - THIS IS THE CRITICAL PART FOR THE TOAST
            await MainActor.run {
                self.successToastMessage = "Update saved successfully!" // Set the binding value
                self.successToastType = .success // <<< NEW: Set the type for success
                self.showSuccessToast = true                          // Set the binding flag
                dismiss() // Then dismiss the current view
            }
            os_log("Update saved successfully.", log: OSLog.default, type: .info)

        } catch {
            os_log("Error saving island: %@", log: OSLog.default, type: .error, error.localizedDescription)
            await MainActor.run {
                showAlert = true
                alertMessage = "Failed to save Update: \(error.localizedDescription)"
                self.successToastMessage = "Failed to save gym: \(error.localizedDescription)" // Set toast message for error
                self.successToastType = .error // <<< NEW: Set the type for error
                self.showSuccessToast = true // Show toast for error too
                // If you show an alert for errors, you might not want a toast simultaneously.
                // Decide which UX you prefer for errors. If you show the alert, maybe don't show the toast.
            }
        }
    }

    private func clearFields() {
        islandDetails.islandName = ""
        islandDetails.multilineAddress = ""
        islandDetails.selectedCountry = nil
        islandDetails.gymWebsite = ""
        islandDetails.latitude = 0.0
        islandDetails.longitude = 0.0
    }
}
