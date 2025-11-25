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
    @ObservedObject var island: PirateIsland
    @EnvironmentObject var pirateIslandViewModel: PirateIslandViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    @StateObject var islandDetails = IslandDetails()
    @StateObject private var countryService = CountryService()
    @State private var isCountryPickerPresented = false

    // MARK: - State Variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Binding var showSuccessToast: Bool
    @Binding var successToastMessage: String
    @Binding var successToastType: ToastView.ToastType

    @State private var originalIslandName: String = ""
    @State private var originalMultilineAddress: String = ""
    @State private var originalSelectedCountryCCA2: String? = nil
    @State private var originalGymWebsite: String = ""

    @State private var createdByName: String = "Loading..."
    @State private var lastModifiedByName: String = "Loading..."
    @State private var displayedCountryName: String = ""

    // MARK: - Initialization
    init(
        island: PirateIsland,
        showSuccessToast: Binding<Bool>,
        successToastMessage: Binding<String>,
        successToastType: Binding<ToastView.ToastType>
    ) {
        _island = ObservedObject(wrappedValue: island)
        _showSuccessToast = showSuccessToast
        _successToastMessage = successToastMessage
        _successToastType = successToastType
    }

    // MARK: - Body
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Gym Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gym Details")
                        .font(.headline)
                    TextField("Gym Name", text: $islandDetails.islandName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body) 
               }

                // Country
                VStack(alignment: .leading, spacing: 6) {
                    Text("Country")
                        .font(.headline)
                    Text(displayedCountryName)
                        .foregroundColor(.primary)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                    
                }

                // Address
                VStack(alignment: .leading, spacing: 6) {
                    Text("Address")
                        .font(.headline)
                    TextEditor(text: $islandDetails.multilineAddress)
                        .frame(minHeight: 100)
                        .border(Color.gray.opacity(0.5), width: 1)
                        .cornerRadius(5)
                }

                // Website
                VStack(alignment: .leading, spacing: 6) {
                    Text("Website (optional)")
                        .font(.headline)
                    TextField("Gym Website", text: $islandDetails.gymWebsite)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .keyboardType(.URL)
                        .onChange(of: islandDetails.gymWebsite) { _, newValue in
                            if !newValue.isEmpty && !validateURL(newValue) {
                                alertMessage = "Invalid website URL"
                                showAlert = true
                            }
                        }
                }

                // Entered By
                VStack(alignment: .leading, spacing: 6) {
                    Text("Entered By")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(createdByName).foregroundColor(.primary)

                }

                // Last Modified By
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last Modified By")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(lastModifiedByName).foregroundColor(.primary)
                }

                // Action Buttons
                actionButtons
            }
            .padding()
            .overlay(
                VStack {
                    Spacer()
                    if showSuccessToast {
                        Text(successToastMessage)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation { showSuccessToast = false }
                                }
                            }
                    }
                }
                .padding()
                .animation(.easeInOut, value: showSuccessToast)
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Edit Gym").font(.title).fontWeight(.bold).foregroundColor(.primary)
                    Text("Ensure all required fields are entered below")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            loadIslandData()
        }
    }

    // MARK: - Helper Methods
    private func loadIslandData() {
        os_log("EditExistingIsland Appeared", log: OSLog.default, type: .info)

        // Initialize islandDetails from Core Data
        islandDetails.islandName = island.islandName ?? ""
        islandDetails.multilineAddress = island.islandLocation ?? ""
        islandDetails.latitude = island.latitude
        islandDetails.longitude = island.longitude
        islandDetails.gymWebsite = island.gymWebsite?.absoluteString ?? ""
        islandDetails.islandID = island.islandID

        displayedCountryName = island.country?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? island.country!
            : "Unknown"

        os_log("Initial Display Values:", log: OSLog.default, type: .info)
        os_log("  islandDetails.islandName: %{public}@", log: OSLog.default, type: .info, islandDetails.islandName)
        os_log("  islandDetails.multilineAddress: %{public}@", log: OSLog.default, type: .info, islandDetails.multilineAddress)
        os_log("  islandDetails.gymWebsite: %{public}@", log: OSLog.default, type: .info, islandDetails.gymWebsite)
        os_log("  island.country: %{public}@", log: OSLog.default, type: .info, island.country ?? "nil")
        os_log("  displayedCountryName: %{public}@", log: OSLog.default, type: .info, displayedCountryName)
        os_log("  island.createdByUserId: %{public}@", log: OSLog.default, type: .info, island.createdByUserId ?? "nil")

        Task {
            await countryService.fetchCountries()

            if let countryCode = island.country,
               let country = countryService.countries.first(where: { $0.cca2 == countryCode }) {
                islandDetails.selectedCountry = country
            } else {
                islandDetails.selectedCountry = nil
            }

            // Store original values
            originalIslandName = islandDetails.islandName
            originalMultilineAddress = islandDetails.multilineAddress
            originalSelectedCountryCCA2 = islandDetails.selectedCountry?.cca2
            originalGymWebsite = islandDetails.gymWebsite

            // Resolve "Entered By"
            if let createdByValue = island.createdByUserId {
                var resolvedName: String?
                resolvedName = await authViewModel.fetchUserName(forUserID: createdByValue)
                if resolvedName == nil {
                    resolvedName = await authViewModel.fetchUserName(forUserName: createdByValue)
                }
                await MainActor.run { self.createdByName = resolvedName ?? "Unknown Creator" }
            } else {
                await MainActor.run { self.createdByName = "N/A (No creator ID/UserName)" }
            }

            // Last Modified By
            if let currentUser = authViewModel.currentUser {
                await MainActor.run { self.lastModifiedByName = currentUser.userName }
            } else {
                await MainActor.run { self.lastModifiedByName = "Not Logged In" }
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
                
                self.successToastMessage = "No changes detected. Please update a field before saving."
                self.successToastType = .error
                self.showSuccessToast = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showSuccessToast = false
                }
            }
            os_log("No changes detected.", log: OSLog.default, type: .info)
            return // do NOT dismiss
        }


        let isIslandNameNonEmpty = !islandDetails.islandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isLocationNonEmpty = !islandDetails.multilineAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard isIslandNameNonEmpty && isLocationNonEmpty else {
            await MainActor.run {
                showAlert = true
                alertMessage = "Please fill in all required fields (Gym Name, Address)."
                
                // Show toast for error
                self.successToastMessage = "Please fill in all required fields (Gym Name, Address)."
                self.successToastType = .error
                self.showSuccessToast = true
                
                // Auto-hide toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showSuccessToast = false
                }
            }
            os_log("Validation failed: required fields missing.", log: OSLog.default, type: .error)
            return // <--- IMPORTANT: exit early, do NOT dismiss
        }


        if !islandDetails.gymWebsite.isEmpty && !validateURL(islandDetails.gymWebsite) {
            await MainActor.run {
                showAlert = true
                alertMessage = "Invalid website URL. Please correct it or leave it empty."

                self.successToastMessage = "Invalid website URL. Please correct it or leave it empty."
                self.successToastType = .error
                self.showSuccessToast = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showSuccessToast = false
                }
            }
            os_log("Validation failed: invalid website URL.", log: OSLog.default, type: .error)
            return // do NOT dismiss
        }


        guard let currentUserId = authViewModel.currentUser?.userID else {
            await MainActor.run {
                showAlert = true
                alertMessage = "User not logged in. Please log in to save."

                self.successToastMessage = "User not logged in. Please log in to save."
                self.successToastType = .error
                self.showSuccessToast = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showSuccessToast = false
                }
            }
            os_log("Current user ID is nil.", log: OSLog.default, type: .error)
            return // do NOT dismiss
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
                self.successToastMessage = "Update saved successfully!"
                self.successToastType = .success
                self.showSuccessToast = true

                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showSuccessToast = false
                }

                dismiss()
            }
            os_log("Update saved successfully.", log: OSLog.default, type: .info)

        } catch {
            os_log("Error saving island: %@", log: OSLog.default, type: .error, error.localizedDescription)
            await MainActor.run {
                showAlert = true
                alertMessage = "Failed to save Update: \(error.localizedDescription)"
                self.successToastMessage = "Failed to save gym: \(error.localizedDescription)"
                self.successToastType = .error
                self.showSuccessToast = true
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
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 14) {
            saveButton
            cancelButton
        }
        .padding(.top, 20)
    }

    // Save button with validation and async save
    private var saveButton: some View {
        Button(action: {
            os_log("Save button clicked", log: OSLog.default, type: .info)
            Task { await saveIsland() }
        }) {
            Text("Save")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)   // Always active
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
    }

    // Cancel button to clear fields and dismiss
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

    
    
    
}
